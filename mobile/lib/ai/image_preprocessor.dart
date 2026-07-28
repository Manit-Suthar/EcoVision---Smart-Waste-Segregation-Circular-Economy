import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  /// Preprocesses an image exactly like the Web version:
  /// 1. Decode image
  /// 2. Center crop to a square
  /// 3. Resize using bilinear interpolation to [inputSize, inputSize]
  /// 4. Extract RGB as a flat Float32List (0.0 to 255.0) in NHWC format
  static Float32List preprocess(Uint8List imageBytes, int inputSize, [String? debugPath]) {
    // 1. Decode image
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception('Failed to decode image.');
    }
    
    // Bake EXIF orientation so the model sees the image upright
    originalImage = img.bakeOrientation(originalImage);

    // 2. Center crop to a square
    int width = originalImage.width;
    int height = originalImage.height;
    int minDim = width < height ? width : height;
    int startX = (width - minDim) ~/ 2;
    int startY = (height - minDim) ~/ 2;

    img.Image croppedImage = img.copyCrop(originalImage, x: startX, y: startY, width: minDim, height: minDim);
    
    // 3. Resize using bilinear interpolation
    img.Image resizedImage = img.copyResize(croppedImage, width: inputSize, height: inputSize, interpolation: img.Interpolation.linear);

    // 4. Extract RGB into a flat Float32List
    Float32List float32Data = Float32List(1 * inputSize * inputSize * 3);
    int bufferIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        img.Pixel pixel = resizedImage.getPixel(x, y);
        
        float32Data[bufferIndex++] = pixel.r.toDouble();
        float32Data[bufferIndex++] = pixel.g.toDouble();
        float32Data[bufferIndex++] = pixel.b.toDouble();
      }
    }

    return float32Data;
  }
}
