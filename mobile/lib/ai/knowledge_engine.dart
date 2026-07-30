import 'package:mobile/ai/config_loader.dart';

class KnowledgeEngine {
  static Map<String, dynamic> getWasteInfo(String predictedClass) {
    if (AiConfigLoader.wasteDatabase == null) {
      return _getDefaultInfo();
    }
    
    final info = AiConfigLoader.wasteDatabase![predictedClass];
    if (info != null) {
      return info as Map<String, dynamic>;
    }
    
    return _getDefaultInfo();
  }

  static List<String> getAllWasteKeys() {
    if (AiConfigLoader.wasteDatabase == null) return [];
    return AiConfigLoader.wasteDatabase!.keys.toList();
  }

  static Map<String, dynamic> _getDefaultInfo() {
    return {
      'Category': 'Unknown',
      'Recyclable': 'Unknown',
      'Dispose In': 'Unknown Bin',
      'Preparation': 'None',
      'google_query': 'waste disposal facility',
    };
  }
}
