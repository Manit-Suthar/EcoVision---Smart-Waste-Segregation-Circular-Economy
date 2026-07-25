import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ai/image_preprocessor.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  test('Image preprocessing creates correctly sized tensor', () {
    // Create a dummy image 300x400
    img.Image dummy = img.Image(width: 300, height: 400);
    // Fill it with red
    for (var p in dummy) {
      p.r = 255;
      p.g = 0;
      p.b = 0;
    }
    
    Uint8List encoded = img.encodePng(dummy);
    
    Float32List tensor = ImagePreprocessor.preprocess(encoded, 224);
    
    expect(tensor.length, 224 * 224 * 3);
    expect(tensor[0], 255.0); // Red
    expect(tensor[1], 0.0);   // Green
    expect(tensor[2], 0.0);   // Blue
  });
}
