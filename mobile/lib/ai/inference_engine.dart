import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class InferenceEngine {
  static OrtSession? session;

  static Future<void> initModel() async {
    try {
      OrtEnv.instance.init();
      
      final rawAssetFile = await rootBundle.load('assets/shared/ecovision_model.onnx');
      final bytes = rawAssetFile.buffer.asUint8List();
      
      final sessionOptions = OrtSessionOptions();
      session = OrtSession.fromBuffer(bytes, sessionOptions);
      
      print('Model Loaded Successfully');
    } catch (e) {
      print('Error initializing model: $e');
      rethrow;
    }
  }

  static void dispose() {
    session?.release();
    session = null;
    OrtEnv.instance.release();
    print('Model Disposed Successfully');
  }

  static Future<Map<String, dynamic>> predict(Float32List inputData, int inputSize) async {
    if (session == null) throw Exception("Session not initialized");

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, inputSize, inputSize, 3],
    );
    
    final runOptions = OrtRunOptions();
    final inputName = session!.inputNames[0];
    
    final inputs = {inputName: inputTensor};
    
    final outputs = session!.run(runOptions, inputs);
    final outputTensor = outputs[0];
    
    final probData = outputTensor?.value as List<dynamic>; 
    final flatProb = (probData[0] as List<dynamic>).map((e) => (e as double)).toList();
    
    int maxIdx = 0;
    double maxProb = flatProb[0];
    for (int i = 1; i < flatProb.length; i++) {
        if (flatProb[i] > maxProb) {
            maxProb = flatProb[i];
            maxIdx = i;
        }
    }
    
    inputTensor.release();
    runOptions.release();
    outputTensor?.release();
    
    return {
      'index': maxIdx,
      'confidence': maxProb * 100,
      'all_probabilities': flatProb,
    };
  }
}
