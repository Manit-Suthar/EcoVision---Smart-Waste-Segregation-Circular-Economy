import 'dart:convert';
import 'package:flutter/services.dart';

class AiConfigLoader {
  static Map<String, dynamic>? config;
  static List<dynamic>? labels;
  static Map<String, dynamic>? wasteDatabase;

  static Future<void> loadAll() async {
    try {
      final configString = await rootBundle.loadString('assets/shared/config.json');
      config = json.decode(configString);

      final labelsString = await rootBundle.loadString('assets/shared/labels.json');
      labels = json.decode(labelsString);

      final wasteDbString = await rootBundle.loadString('assets/shared/waste_database.json');
      wasteDatabase = json.decode(wasteDbString);
      
      print('AI Config Loader: Successfully loaded all shared assets.');
      print('Config items: ${config?.keys.length}');
      print('Labels count: ${labels?.length}');
      print('Waste DB categories: ${wasteDatabase?.keys.length}');
    } catch (e) {
      print('AI Config Loader Error: $e');
      rethrow;
    }
  }
}
