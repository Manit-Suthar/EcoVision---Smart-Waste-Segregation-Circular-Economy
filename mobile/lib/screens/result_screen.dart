import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ai/config_loader.dart';
import '../widgets/premium_background.dart';
import '../widgets/brand_app_bar.dart';
import 'camera_screen.dart';
import 'map_screen.dart';
import '../ai/image_preprocessor.dart';
import '../ai/inference_engine.dart';
import '../ai/knowledge_engine.dart';
import '../services/gamification_service.dart';
import '../services/feedback_service.dart';
import 'civic_complaint_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_background.dart';

Float32List _isolatePreprocess(Map<String, dynamic> args) {
  return ImagePreprocessor.preprocess(args['bytes'], args['size'], null);
}

class ResultScreen extends StatefulWidget {
  final String? imagePath;
  final String? predictedClass; // renamed for passing from history
  final bool isSearch;
  
  const ResultScreen({super.key, this.imagePath, this.predictedClass, this.isSearch = false});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isPredicting = true;
  String _predClass = '';
  double _predConf = 0.0;
  List<double>? _allProbs;
  Map<String, dynamic> _wasteInfo = {};
  String? _errorMessage;
  bool _logged = false;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    if (widget.predictedClass != null) {
      _isPredicting = false;
      _predClass = widget.predictedClass!;
      _selectedCategory = widget.predictedClass!;
      _wasteInfo = KnowledgeEngine.getWasteInfo(_predClass);
    } else {
      _runPrediction();
    }
  }

  Future<void> _runPrediction() async {
    try {
      if (widget.imagePath == null) throw Exception("No image provided");
      
      final File imageFile = File(widget.imagePath!);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final int inputSize = AiConfigLoader.config?['input_size'] ?? 224;
      
      final Float32List preprocessedData = await compute(
        _isolatePreprocess, 
        {'bytes': imageBytes, 'size': inputSize}
      );
      
      final result = await InferenceEngine.predict(preprocessedData, inputSize);
      
      final int maxIdx = result['index'];
      final double conf = result['confidence'];
      final List<double> allProbs = result['all_probabilities'];
      
      String predictedLabel = AiConfigLoader.labels?[maxIdx] ?? 'Unknown';
      final double threshold = (AiConfigLoader.config?['confidence_threshold'] ?? 65.0).toDouble();
      
      if (conf < threshold || predictedLabel == 'Non_Waste') {
        predictedLabel = 'Non_Waste';
      }
      
      final info = KnowledgeEngine.getWasteInfo(predictedLabel);

      if (mounted) {
        setState(() {
          _predClass = predictedLabel;
          _selectedCategory = predictedLabel;
          _predConf = conf;
          _allProbs = allProbs;
          _wasteInfo = info;
          _isPredicting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isPredicting = false;
        });
      }
    }
  }

  Future<void> _logScan() async {
    if (_logged || widget.isSearch || widget.predictedClass != null && widget.imagePath == null) return;
    
    if (_selectedCategory != 'Non_Waste') {
      int score = KnowledgeEngine.getGreenScore(_selectedCategory);
      await GamificationService.addPoints(score);
      await GamificationService.addCarbonOffset(0.5);
      
      final info = KnowledgeEngine.getWasteInfo(_selectedCategory);
      await _saveToHistory(_selectedCategory, info['Category'] ?? 'Unknown', _predConf);
    }
    setState(() { _logged = true; });
  }

  Future<void> _saveToHistory(String className, String category, double confidence) async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString('scan_history');
    List<dynamic> history = historyString != null ? jsonDecode(historyString) : [];
    history.add({
      'class_name': className,
      'category': category,
      'confidence': confidence,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (history.length > 50) history.removeAt(0);
    await prefs.setString('scan_history', jsonEncode(history));
  }

  String _getScrapValue(String category) {
    final lower = category.toLowerCase();
    if(lower.contains('metal')) return '₹20 - ₹200/kg';
    if(lower.contains('e-waste') || lower.contains('smartphone')) return '₹150 - ₹500/kg';
    if(lower.contains('plastic')) return '₹8 - ₹12/kg';
    if(lower.contains('paper') || lower.contains('cardboard')) return '₹10 - ₹15/kg';
    if(lower.contains('glass')) return '₹2 - ₹5/kg';
    return 'No significant scrap value';
  }

  Color _getThemeColor(String bin) {
    if (bin.toLowerCase().contains('green') || bin.toLowerCase().contains('organic')) return const Color(0xFF16a34a);
    if (bin.toLowerCase().contains('blue') || bin.toLowerCase().contains('recycle')) return const Color(0xFF3b82f6);
    if (bin.toLowerCase().contains('red') || bin.toLowerCase().contains('hazard')) return const Color(0xFFef4444);
    if (bin.toLowerCase().contains('black')) return const Color(0xFF1e293b);
    return const Color(0xFF16a34a);
  }

  @override
  Widget build(BuildContext context) {
    if (_isPredicting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(widget.imagePath!), height: 120, width: 120, fit: BoxFit.cover),
                ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Analyzing waste...', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }

    final String title = _predClass.replaceAll('_', ' ');
    final String bin = _wasteInfo['Dispose In'] ?? 'General Bin';
    final Color themeColor = _getThemeColor(bin);

    return Scaffold(
      
      appBar: const BrandAppBar(),
      body: PremiumBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Card (AI Detection / Confirm to earn points)
              _buildPremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      padding: const EdgeInsets.only(bottom: 8),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        widget.imagePath != null ? 'AI Detection' : (widget.isSearch ? 'Search Result' : 'History Result'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: themeColor),
                    ),
                    const SizedBox(height: 8),
                    if (widget.imagePath != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(16)),
                            child: Text('Confidence: ${_predConf.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(16)),
                            child: const Text('Time: 120ms', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    
                    if (widget.imagePath != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const CameraScreen()),
                            );
                          },
                          child: Image.file(
                            File(widget.imagePath!),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    if (widget.imagePath != null) ...[
                      const SizedBox(height: 24),
                      const Text('Confirm Category to Earn Points:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF16A34A)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedCategory,
                            items: [
                              ...AiConfigLoader.labels!.map((l) => DropdownMenuItem(value: l, child: Text(l))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCategory = val;
                                  _wasteInfo = KnowledgeEngine.getWasteInfo(val);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _logged ? null : _logScan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _logged ? Colors.grey : const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(_logged ? (_selectedCategory == 'Non_Waste' ? 'Ignored (Non-Waste)' : 'Logged!') : 'Confirm & Log Scan', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    if (_allProbs != null && _allProbs!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: const Text('▶ View All Predictions', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 14)),
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.all(8),
                          backgroundColor: Colors.white,
                          collapsedBackgroundColor: Colors.white,
                          children: [
                            for (int i = 0; i < _allProbs!.length; i++)
                              if (_allProbs![i] * 100 > 0.5)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(AiConfigLoader.labels?[i] ?? '', style: const TextStyle(fontSize: 12)),
                                          Text('${(_allProbs![i]*100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: _allProbs![i],
                                        backgroundColor: const Color(0xFFCBD5E1),
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ],
                                  ),
                                )
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),

              // 2. Est Scrap Value
              _buildPremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Est. Scrap Value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Divider(color: Color(0xFFE2E8F0), height: 24),
                    Text(
                      _getScrapValue((_wasteInfo['Category'] ?? '') + ' ' + _predClass),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                    ),
                    const Text('Values are estimates only', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),

              // 3. Handling & Impact
              _buildPremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Handling & Impact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Divider(color: Color(0xFFE2E8F0), height: 24),
                    Text('Dispose In:', style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                    const SizedBox(height: 4),
                    Text(bin, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    const Text('Environmental Impact:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    const SizedBox(height: 4),
                    Text(_wasteInfo['Environmental Impact'] ?? 'Unknown', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    const Text('Recycling Process:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                    const SizedBox(height: 4),
                    Text(_wasteInfo['Recycling Process'] ?? 'N/A', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),

              // 4. Nearby Facilities
              _buildPremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nearby Facilities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Divider(color: Color(0xFFE2E8F0), height: 24),
                    _buildFacility('Ahmedabad Kabaadi Market', 'Gheekanta, Ahmedabad', '~2.1 km'),
                    _buildFacility('EcoRecycle Center', 'Navrangpura, Ahmedabad', '~3.5 km'),
                    _buildFacility('Green Waste Solutions', 'SG Highway, Ahmedabad', '~5.0 km'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                              String query = "recycling near me";
                              if (_wasteInfo['Category']?.toLowerCase().contains('e-waste') ?? false) query = "e-waste recycling";
                              if (_wasteInfo['Category']?.toLowerCase().contains('plastic') ?? false) query = "plastic recycling";
                              if (_wasteInfo['Category']?.toLowerCase().contains('garbage') ?? false) query = "dumpster";
                              if (_wasteInfo['Category']?.toLowerCase().contains('metal') ?? false) query = "scrap metal yard";
                              if (_wasteInfo['Category']?.toLowerCase().contains('paper') ?? false) query = "paper recycling";
                              if (_wasteInfo['Category']?.toLowerCase().contains('e-waste') ?? false || _wasteInfo['Category']?.toLowerCase().contains('battery') ?? false) query = "e-waste recycling";
                              if (_wasteInfo['Category']?.toLowerCase().contains('organic') ?? false) query = "compost facility";
                              if (_wasteInfo['Category']?.toLowerCase().contains('glass') ?? false) query = "glass recycling";
                              if (_wasteInfo['Category']?.toLowerCase().contains('sanitary') ?? false) query = "sanitary waste disposal";
                              
                              String mapUrl = "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}";
                              
                              try {
                                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                if (serviceEnabled) {
                                  LocationPermission permission = await Geolocator.checkPermission();
                                  if (permission == LocationPermission.denied) {
                                    permission = await Geolocator.requestPermission();
                                  }
                                  if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
                                    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                                    mapUrl = "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query.replaceAll(' near me', ''))}&query_place_id=${position.latitude},${position.longitude}";
                                  }
                                }
                              } catch (e) {
                                debugPrint("Location error: $e");
                              }
                              
                              final Uri url = Uri.parse(mapUrl);
                              if (!await launchUrl(url)) {
                                debugPrint("Could not launch $url");
                              }
                            },
                        icon: const Icon(Icons.map),
                        label: const Text('Search on Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildFacility(String name, String address, String distance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontSize: 14)),
              Text(address, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
          Text(distance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
