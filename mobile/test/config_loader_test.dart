import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ai/config_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Config loader correctly parses JSON assets', () async {
    await AiConfigLoader.loadAll();
    expect(AiConfigLoader.config, isNotNull);
    expect(AiConfigLoader.labels, isNotNull);
    expect(AiConfigLoader.wasteDatabase, isNotNull);
    
    // Check some known values to verify parsing
    expect(AiConfigLoader.config!['input_size'], 224);
  });
}
