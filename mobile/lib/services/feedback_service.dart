import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackService {
  static const String _queueKey = 'feedback_training_queue';

  /// Adds a corrected prediction to the local training queue
  static Future<void> addCorrection(String imagePath, String originalPrediction, String correctedLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString(_queueKey);
    List<dynamic> queue = [];
    if (queueString != null) {
      queue = jsonDecode(queueString);
    }
    queue.add({
      'image_path': imagePath,
      'original_prediction': originalPrediction,
      'corrected_label': correctedLabel,
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Keep last 100 items to avoid bloating
    if (queue.length > 100) queue.removeAt(0);
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString(_queueKey);
    if (queueString != null) {
      final List<dynamic> decoded = jsonDecode(queueString);
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
