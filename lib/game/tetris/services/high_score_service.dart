import 'package:shared_preferences/shared_preferences.dart';

class HighScoreService {
  static const String _highScoreKey = 'tetris_high_score';

  Future<int> getHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final score = prefs.getInt(_highScoreKey) ?? 0;
      return score >= 0 ? score : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveHighScore(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_highScoreKey, score);
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> clearHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_highScoreKey);
    } catch (_) {
      // Silently fail
    }
  }
}
