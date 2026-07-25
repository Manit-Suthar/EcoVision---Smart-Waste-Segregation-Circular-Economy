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
}
