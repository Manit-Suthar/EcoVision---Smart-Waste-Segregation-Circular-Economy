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

  static int getScrapValue(String predictedClass) {
    String p = predictedClass.toLowerCase();
    if (p.contains('e-waste') || p.contains('battery')) return 150;
    if (p.contains('metal') || p.contains('can')) return 40;
    if (p.contains('plastic') || p.contains('bottle')) return 15;
    if (p.contains('paper') || p.contains('cardboard')) return 5;
    if (p.contains('glass')) return 10;
    return 0; // Organic or non-recyclables usually have no direct monetary scrap value for end-users
  }

  static int getGreenScore(String predictedClass) {
    String p = predictedClass.toLowerCase();
    if (p.contains('e-waste') || p.contains('battery')) return 50;
    if (p.contains('metal')) return 30;
    if (p.contains('plastic')) return 20;
    if (p.contains('paper')) return 10;
    if (p.contains('organic')) return 15;
    return 5;
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
