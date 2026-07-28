import 'package:shared_preferences/shared_preferences.dart';

class GamificationService {
  static const String _pointsKey = 'green_points';
  static const String _carbonOffsetKey = 'carbon_offset';

  static Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  static Future<void> addPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_pointsKey) ?? 0;
    await prefs.setInt(_pointsKey, current + points);
  }

  static Future<double> getCarbonOffset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_carbonOffsetKey) ?? 0.0;
  }

  static Future<void> addCarbonOffset(double kg) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_carbonOffsetKey) ?? 0.0;
    await prefs.setDouble(_carbonOffsetKey, current + kg);
  }
}
