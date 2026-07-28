import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../ai/config_loader.dart';
import 'map_screen.dart';
import '../ai/image_preprocessor.dart';
import '../ai/inference_engine.dart';
import '../ai/knowledge_engine.dart';
import '../services/gamification_service.dart';
import '../services/feedback_service.dart';
import 'civic_complaint_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

Float32List _isolatePreprocess(Map<String, dynamic> args) {
  return ImagePreprocessor.preprocess(args['bytes'], args['size'], null);
}

class ResultScreen extends StatefulWidget {
  final String imagePath;
  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isPredicting = true;
  String _predClass = '';
  double _predConf = 0.0;
  List<double> _allProbs = [];
  Map<String, dynamic> _wasteInfo = {};
  String? _errorMessage;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _runPrediction();
  }

  Future<void> _runPrediction() async {
    try {
      final File imageFile = File(widget.imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final int inputSize = AiConfigLoader.config?['input_size'] ?? 224;
      
      final Float32List preprocessedData = await compute(
        _isolatePreprocess, 
        {'bytes': imageBytes, 'size': inputSize}
      );
      
      final result = await InferenceEngine.predict(preprocessedData, inputSize);
      
      final int maxIdx = result['index'];
      final double conf = result['confidence'];
      
      String predictedLabel = AiConfigLoader.labels?[maxIdx] ?? 'Unknown';
      
      final num thresholdNum = AiConfigLoader.config?['confidence_threshold'] ?? 65.0;
      final double threshold = thresholdNum.toDouble();
      
      if (conf < threshold || predictedLabel == 'Non_Waste') {
        predictedLabel = 'Uncertain / Non Waste';
      }
      
      final info = KnowledgeEngine.getWasteInfo(predictedLabel == 'Uncertain / Non Waste' ? 'Unknown' : predictedLabel);

      if (mounted) {
        setState(() {
          _predClass = predictedLabel;
          _selectedCategory = predictedLabel;
          _predConf = conf;
          _allProbs = result['all_probabilities'] != null ? List<double>.from(result['all_probabilities']) : [];
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

  String _selectedCategory = '';

  Future<void> _logScan() async {
    if (_logged) return;
    
    // Save to feedback queue if the user changed the category
    if (_selectedCategory != _predClass) {
      await FeedbackService.addCorrection(widget.imagePath, _predClass, _selectedCategory);
    }
    
    // Add points & offset only if it's confirmed as a valid waste type (not non_waste)
    if (_selectedCategory != 'Non_Waste' && _selectedCategory != 'Uncertain / Non Waste') {
      await GamificationService.addPoints(10);
      
      double offset = 0.5; // Base offset
      if (_selectedCategory.toLowerCase() == 'e-waste') offset = 5.0;
      if (_selectedCategory.toLowerCase() == 'metal waste') offset = 3.0;
      if (_selectedCategory.toLowerCase() == 'plastic waste') offset = 1.5;
      
      await GamificationService.addCarbonOffset(offset);
      
      // Save to history using knowledge engine category if available
      final info = KnowledgeEngine.getWasteInfo(_selectedCategory);
      await _saveToHistory(_selectedCategory, info['Category'] ?? 'Unknown', _predConf);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan logged! +10 Green Points'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as Non-Waste.'), backgroundColor: Colors.grey),
        );
      }
    }

    setState(() {
      _logged = true;
    });
  }

  Future<void> _saveToHistory(String className, String category, double confidence) async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString('scan_history');
    List<dynamic> history = [];
    if (historyString != null) {
      history = jsonDecode(historyString);
    }
    history.add({
      'class_name': className,
      'category': category,
      'confidence': confidence,
      'timestamp': DateTime.now().toIso8601String(),
    });
    // keep last 50
    if (history.length > 50) history.removeAt(0);
    await prefs.setString('scan_history', jsonEncode(history));
  }

  String _getScrapValue(String category) {
    switch (category.toLowerCase()) {
      case 'e-waste': return '₹150 - ₹500/kg';
      case 'metal waste': return '₹20 - ₹200/kg';
      case 'paper waste': return '₹10 - ₹15/kg';
      case 'plastic waste': return '₹8 - ₹12/kg';
      case 'glass waste': return '₹2 - ₹5/kg';
      case 'automobile wastes': return 'Variable by part';
      default: return 'No significant scrap value';
    }
  }

  void _openGoogleMaps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(category: _predClass),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPredicting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(widget.imagePath), height: 200, width: 200, fit: BoxFit.cover),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 16),
              const Text('Analyzing waste...', style: TextStyle(color: Colors.white70, fontSize: 16)),
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.file(File(widget.imagePath), fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('AI PREDICTION', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Text(
                          _predClass.toUpperCase(),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _buildConfidenceRow(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_allProbs.isNotEmpty) _buildAllPredictionsCard(),
                  const SizedBox(height: 16),
                  if (_selectedCategory != 'Uncertain / Non Waste' && _selectedCategory != 'Non_Waste') ...[
                    _buildIncentivesCard(),
                    const SizedBox(height: 16),
                    _buildDisposalCard(),
                    const SizedBox(height: 16),
                    _buildKnowledgeCard(),
                    const SizedBox(height: 24),
                  ],
                  _buildConfirmationBlock(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CivicComplaintScreen(category: _predClass)));
                          },
                          icon: const Icon(Icons.report_problem, color: Colors.orangeAccent),
                          label: const Text('Report Issue', style: TextStyle(color: Colors.orangeAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orangeAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('AI Confidence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _predConf > 80 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _predConf > 80 ? Colors.green : Colors.orange),
          ),
          child: Text(
            '${_predConf.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _predConf > 80 ? Colors.greenAccent : Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllPredictionsCard() {
    final labels = AiConfigLoader.labels ?? [];
    if (labels.isEmpty || _allProbs.length != labels.length) return const SizedBox.shrink();

    // Map labels to probabilities, filter out tiny ones, and sort
    final sorted = List.generate(labels.length, (i) => {'label': labels[i], 'prob': _allProbs[i] * 100})
        .where((e) => (e['prob'] as double) > 0.1) // show > 0.1%
        .toList()
        ..sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: const Text('View All Predictions', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        children: sorted.map((e) {
          final l = e['label'] as String;
          final p = e['prob'] as double;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.toUpperCase(), style: const TextStyle(fontSize: 14)),
                Text('${p.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIncentivesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.currency_rupee, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Est. Scrap Value:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getScrapValue(_predClass), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisposalCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Disposal Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _infoRow('Dispose In', _wasteInfo['Dispose In']),
            _infoRow('Recyclable', _wasteInfo['Recyclable']),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openGoogleMaps,
                icon: const Icon(Icons.map),
                label: const Text('Find Nearby Centers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ExpansionTile(
            title: const Text('Preparation & Handling', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.build, color: Colors.blueAccent),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Prep Steps', _wasteInfo['Preparation Steps']),
                    _infoRow('Warning', _wasteInfo['Disposal Warnings'], color: Colors.redAccent),
                  ],
                ),
              )
            ],
          ),
          ExpansionTile(
            title: const Text('Impact & Facts', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.public, color: Colors.greenAccent),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Environmental Impact', _wasteInfo['Environmental Impact']),
                    _infoRow('Recycling Process', _wasteInfo['Recycling Process']),
                    _infoRow('Common Mistakes', _wasteInfo['Common Mistakes'], color: Colors.amberAccent),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, {Color? color}) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.white),
            ),
            TextSpan(text: value.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationBlock() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.greenAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Help us improve! Please confirm or correct the AI prediction before logging.', style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(4),
                color: Colors.black26,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory.isEmpty || !AiConfigLoader.labels!.contains(_selectedCategory) ? AiConfigLoader.labels!.first : _selectedCategory,
                  dropdownColor: Colors.grey.shade900,
                  items: AiConfigLoader.labels?.map((label) {
                    return DropdownMenuItem<String>(
                      value: label,
                      child: Text(label),
                    );
                  }).toList() ?? [],
                  onChanged: _logged ? null : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                        _wasteInfo = KnowledgeEngine.getWasteInfo(value == 'Non_Waste' ? 'Unknown' : value);
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logged ? null : _logScan,
                icon: Icon(_logged ? Icons.check : Icons.add_circle),
                label: Text(_logged ? 'Logged Successfully' : 'Confirm & Log Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _logged ? Colors.grey.shade700 : Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
