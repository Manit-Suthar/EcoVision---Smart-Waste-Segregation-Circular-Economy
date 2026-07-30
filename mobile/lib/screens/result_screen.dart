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
import '../theme/app_theme.dart';

Float32List _isolatePreprocess(Map<String, dynamic> args) {
  return ImagePreprocessor.preprocess(args['bytes'], args['size'], null);
}

class ResultScreen extends StatefulWidget {
  final String? imagePath;
  final String? categoryKey;
  final bool isSearch;
  
  const ResultScreen({super.key, this.imagePath, this.categoryKey, this.isSearch = false});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isPredicting = true;
  String _predClass = '';
  double _predConf = 0.0;
  Map<String, dynamic> _wasteInfo = {};
  String? _errorMessage;
  bool _logged = false;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    if (widget.isSearch && widget.categoryKey != null) {
      _isPredicting = false;
      _predClass = widget.categoryKey!;
      _selectedCategory = widget.categoryKey!;
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
    if (_logged || widget.isSearch) return;
    
    if (_selectedCategory != _predClass && widget.imagePath != null) {
      await FeedbackService.addCorrection(widget.imagePath!, _predClass, _selectedCategory);
    }
    
    if (_selectedCategory != 'Non_Waste' && _selectedCategory != 'Uncertain / Non Waste') {
      await GamificationService.addPoints(10);
      
      double offset = 0.5;
      if (_selectedCategory.toLowerCase() == 'e-waste') offset = 5.0;
      if (_selectedCategory.toLowerCase() == 'metal waste') offset = 3.0;
      if (_selectedCategory.toLowerCase() == 'plastic waste') offset = 1.5;
      
      await GamificationService.addCarbonOffset(offset);
      
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

  Color _getThemeColor(String bin) {
    if (bin.toLowerCase().contains('green') || bin.toLowerCase().contains('organic')) return AppTheme.primaryColor;
    if (bin.toLowerCase().contains('blue') || bin.toLowerCase().contains('recycle')) return AppTheme.infoColor;
    if (bin.toLowerCase().contains('red') || bin.toLowerCase().contains('hazard')) return AppTheme.errorColor;
    return AppTheme.textSecondary;
  }

  IconData _getBinIcon(String bin) {
    if (bin.toLowerCase().contains('green') || bin.toLowerCase().contains('organic')) return Icons.eco;
    if (bin.toLowerCase().contains('blue') || bin.toLowerCase().contains('recycle')) return Icons.recycling;
    if (bin.toLowerCase().contains('red') || bin.toLowerCase().contains('hazard')) return Icons.warning_amber_rounded;
    return Icons.delete_outline;
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
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorColor))),
      );
    }

    final String title = _predClass.replaceAll('_', ' ');
    final String bin = _wasteInfo['Dispose In'] ?? 'General Bin';
    final Color themeColor = _getThemeColor(bin);
    final IconData binIcon = _getBinIcon(bin);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSearch ? 'Knowledge Base' : 'Scan Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Row(
              children: [
                if (widget.imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(widget.imagePath!), height: 80, width: 80, fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: Icon(binIcon, color: themeColor, size: 40),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      if (!widget.isSearch)
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 16, color: AppTheme.infoColor),
                            const SizedBox(width: 4),
                            Text('AI Confidence: ${(_predConf * 100).toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.infoColor, fontWeight: FontWeight.bold)),
                          ],
                        )
                      else
                        const Row(
                          children: [
                            Icon(Icons.menu_book, size: 16, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Text('Database Result', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Disposal Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border(top: BorderSide(color: themeColor, width: 4)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0,4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Dispose In', style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16)),
                      Icon(binIcon, color: themeColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(bin, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(_wasteInfo['Environmental Impact'] ?? '', style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Gamification Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        const Icon(Icons.monetization_on, color: AppTheme.warningColor),
                        const SizedBox(height: 8),
                        Text(_getScrapValue(_predClass), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                        const Text('Est. Scrap Value', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16)),
                    child: const Column(
                      children: [
                        Icon(Icons.star, color: Color(0xFF8B5CF6)),
                        SizedBox(height: 8),
                        Text('+10 pts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Green Reward', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Process Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.recycling, size: 20),
                      SizedBox(width: 8),
                      Text('Recycling Process', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_wasteInfo['Recycling Process'] ?? 'N/A', style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
                  const SizedBox(height: 16),
                  const Text('Common Mistakes', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warningColor)),
                  const SizedBox(height: 4),
                  Text(_wasteInfo['Common Mistakes'] ?? 'None noted.', style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            if (!widget.isSearch) ...[
              ElevatedButton.icon(
                onPressed: _logged ? null : _logScan,
                icon: Icon(_logged ? Icons.check_circle : Icons.verified),
                label: Text(_logged ? 'Scan Logged' : 'Log Scan & Claim Points'),
              ),
              const SizedBox(height: 12),
            ],
            
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen(category: _predClass)));
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Find Nearby Facilities'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppTheme.infoColor),
                foregroundColor: AppTheme.infoColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CivicComplaintScreen(category: _predClass)));
              },
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Report Civic Issue'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
