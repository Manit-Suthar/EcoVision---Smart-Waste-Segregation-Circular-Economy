import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../ai/config_loader.dart';
import '../ai/image_preprocessor.dart';
import '../ai/inference_engine.dart';
import '../ai/knowledge_engine.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedImage;
  bool _isPredicting = false;
  
  String _predClass = '';
  String _predConf = '';
  Map<String, dynamic> _wasteInfo = {};
  
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _predClass = '';
        _predConf = '';
        _wasteInfo = {};
      });
    }
  }

  Future<void> _runPrediction() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isPredicting = true;
    });

    try {
      final Uint8List imageBytes = await _selectedImage!.readAsBytes();
      final int inputSize = AiConfigLoader.config?['input_size'] ?? 224;
      
      final Float32List preprocessedData = ImagePreprocessor.preprocess(imageBytes, inputSize);
      
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

      setState(() {
        _predClass = predictedLabel;
        _predConf = '${conf.toStringAsFixed(1)}%';
        _wasteInfo = info;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prediction Failed: $e')),
      );
    } finally {
      setState(() {
        _isPredicting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoVision - AI Core Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 300, fit: BoxFit.cover)
            else
              Container(
                height: 300,
                color: Colors.grey[300],
                child: const Center(child: Text('No Image Selected')),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Select Image from Gallery'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isPredicting || _selectedImage == null ? null : _runPrediction,
              child: _isPredicting 
                  ? const CircularProgressIndicator()
                  : const Text('Run Prediction'),
            ),
            const SizedBox(height: 30),
            if (_predClass.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class: $_predClass', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Confidence: $_predConf', style: const TextStyle(fontSize: 16)),
                      const Divider(),
                      Text('Category: ${_wasteInfo['Category'] ?? '-'}'),
                      Text('Recyclable: ${_wasteInfo['Recyclable'] ?? '-'}'),
                      Text('Bin: ${_wasteInfo['Dispose In'] ?? '-'}'),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
