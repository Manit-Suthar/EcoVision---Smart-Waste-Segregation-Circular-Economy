import re
import os

# 1. Update image_preprocessor.dart
with open('mobile/lib/ai/image_preprocessor.dart', 'r') as f:
    prep = f.read()

prep = prep.replace("import 'package:image/image.dart' as img;", "import 'package:image/image.dart' as img;\nimport 'dart:io';\nimport 'dart:math';")

prep = prep.replace("static Float32List preprocess(Uint8List imageBytes, int inputSize) {", "static Float32List preprocess(Uint8List imageBytes, int inputSize, [String? debugPath]) {\n    print('[PARITY] Stage 1 - Image Loading');")

prep = prep.replace("img.Image? originalImage = img.decodeImage(imageBytes);", "img.Image? originalImage = img.decodeImage(imageBytes);\n    print('[PARITY] Original Width: ${originalImage?.width}');\n    print('[PARITY] Original Height: ${originalImage?.height}');")
prep = prep.replace("originalImage = img.bakeOrientation(originalImage);", "originalImage = img.bakeOrientation(originalImage);\n    print('[PARITY] Orientation: Explicitly baked via img.bakeOrientation()');\n\n    print('[PARITY] Stage 2 - Cropping');")

prep = prep.replace("int minDim = width < height ? width : height;", "int minDim = width < height ? width : height;\n    print('[PARITY] Crop Start X: $startX');\n    print('[PARITY] Crop Start Y: $startY');\n    print('[PARITY] Crop Width: $minDim');\n    print('[PARITY] Crop Height: $minDim');\n    if (debugPath != null) {\n      final cropImage = img.copyCrop(originalImage, x: startX, y: startY, width: minDim, height: minDim);\n      File('$debugPath/flutter_crop.png').writeAsBytesSync(img.encodePng(cropImage));\n      print('[PARITY] Saved flutter_crop.png to $debugPath');\n    }\n    print('[PARITY] Stage 3 - Resize');")

prep = prep.replace("img.Image resizedImage = img.copyResize(originalImage,", "img.Image croppedImage = img.copyCrop(originalImage, x: startX, y: startY, width: minDim, height: minDim);\n    img.Image resizedImage = img.copyResize(croppedImage,")

prep = prep.replace("Float32List float32Data = Float32List(1 * inputSize * inputSize * 3);", "if (debugPath != null) {\n      File('$debugPath/flutter_resize.png').writeAsBytesSync(img.encodePng(resizedImage));\n      print('[PARITY] Saved flutter_resize.png to $debugPath');\n    }\n\n    Float32List float32Data = Float32List(1 * inputSize * inputSize * 3);")

stats = """
    print('[PARITY] Stage 4 - Tensor Generation');
    print('[PARITY] Tensor Shape: [1, $inputSize, $inputSize, 3]');
    print('[PARITY] Tensor Length: ${float32Data.length}');
    double minV = double.infinity, maxV = double.negativeInfinity, sum = 0;
    for (var v in float32Data) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
      sum += v;
    }
    double mean = sum / float32Data.length;
    double sqSum = 0;
    for (var v in float32Data) sqSum += pow(v - mean, 2);
    double stdDev = sqrt(sqSum / float32Data.length);
    print('[PARITY] Min Value: $minV');
    print('[PARITY] Max Value: $maxV');
    print('[PARITY] Mean: $mean');
    print('[PARITY] Std Dev: $stdDev');
    print('[PARITY] First 20 floats: [${float32Data.sublist(0, 20).join(', ')}]');
    print('[PARITY] Middle 20 floats: [${float32Data.sublist(float32Data.length~/2, (float32Data.length~/2)+20).join(', ')}]');
    print('[PARITY] Last 20 floats: [${float32Data.sublist(float32Data.length-20).join(', ')}]');
    return float32Data;
"""
prep = prep.replace("return float32Data;", stats)

with open('mobile/lib/ai/image_preprocessor.dart', 'w') as f:
    f.write(prep)

# 2. Update home_screen.dart
with open('mobile/lib/screens/home_screen.dart', 'r') as f:
    home = f.read()

home = home.replace("import 'package:image_picker/image_picker.dart';", "import 'package:image_picker/image_picker.dart';\nimport 'package:path_provider/path_provider.dart';\nimport 'package:crypto/crypto.dart';\nimport 'package:flutter/services.dart';")

home = home.replace("return ImagePreprocessor.preprocess(args['bytes'], args['size']);", "return ImagePreprocessor.preprocess(args['bytes'], args['size'], args['debugPath']);")

home = home.replace("Future<void> _runPrediction() async {", """
  Future<String> getChecksum(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final digest = sha256.convert(data.buffer.asUint8List());
    return digest.toString();
  }

  Future<void> _runPrediction() async {
    print('[PARITY] Stage 0 - Environment Verification (Flutter)');
    print('[PARITY] config.json SHA-256: ${await getChecksum("assets/shared/config.json")}');
    print('[PARITY] labels.json SHA-256: ${await getChecksum("assets/shared/labels.json")}');
    print('[PARITY] waste_database.json SHA-256: ${await getChecksum("assets/shared/waste_database.json")}');
    print('[PARITY] ecovision_model.onnx SHA-256: ${await getChecksum("assets/shared/ecovision_model.onnx")}');
""")

home = home.replace("{'bytes': imageBytes, 'size': inputSize}", """{
          'bytes': imageBytes, 
          'size': inputSize, 
          'debugPath': (await getApplicationDocumentsDirectory()).path
        }""")

home = home.replace("setState(() {", """
      final probs = (result['all_probabilities'] as List<dynamic>).map((e) => e as double).toList();
      print('[PARITY] Stage 6 - Raw ONNX Output');
      print('[PARITY] Raw Output Vector: [${probs.join(', ')}]');
      
      int maxIndex = 0;
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > probs[maxIndex]) maxIndex = i;
      }
      print('[PARITY] Argmax Index: $maxIndex');

      final confidence = result['confidence'] as double;
      final className = result['class_name'] as String;
      final threshold = AiConfigLoader.config?['confidence_threshold'] ?? 65.0;
      
      print('[PARITY] Stage 7 - Label Mapping');
      String finalResult = className;
      if (className == 'Non_Waste' || confidence < threshold) finalResult = 'Uncertain / Non Waste';
      print('[PARITY] Index: $maxIndex -> Label: $className -> Category: ${result['waste_info']?['Category']} -> Confidence: $confidence% -> Threshold: $threshold -> Final Result: $finalResult');

      setState(() {""")

with open('mobile/lib/screens/home_screen.dart', 'w') as f:
    f.write(home)

# 3. Update inference_engine.dart
with open('mobile/lib/ai/inference_engine.dart', 'r') as f:
    inf = f.read()

inf = inf.replace("final runOptions = OrtRunOptions();", """
      print('[PARITY] Stage 5 - Model Input Metadata');
      print('[PARITY] Input Name: ${session?.inputNames[0]}');
      print('[PARITY] Output Name: ${session?.outputNames[0]}');
      print('[PARITY] Input Shape: Expected [1, $inputSize, $inputSize, 3]');
      print('[PARITY] Tensor Type: float32');
      final runOptions = OrtRunOptions();""")

with open('mobile/lib/ai/inference_engine.dart', 'w') as f:
    f.write(inf)

