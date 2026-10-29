import 'package:hive_flutter/hive_flutter.dart';

/// Ключи рекордов по режимам.
const String kBestUltraKey = 'best_ultra';
const String kBestSprintKey = 'best_sprint_ms';

abstract class GameLocalDataSource {
  Future<int> getHighScore();
  Future<void> saveHighScore(int score);

  /// Рекорд по ключу (0 — рекорда ещё нет).
  Future<int> getBest(String key);
  Future<void> saveBest(String key, int value);

  Future<void> saveGame(Map<String, dynamic> data);
  Future<Map<String, dynamic>?> loadGame();
  Future<void> clearGame();
}

class GameLocalDataSourceImpl implements GameLocalDataSource {
  static const String _boxName = 'cyber_brick_box';
  static const String _highScoreKey = 'high_score';
  static const String _savedGameKey = 'saved_game';

  @override
  Future<int> getHighScore() async {
    final box = await Hive.openBox(_boxName);
    return box.get(_highScoreKey, defaultValue: 0) as int;
  }

  @override
  Future<void> saveHighScore(int score) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_highScoreKey, score);
  }

  @override
  Future<int> getBest(String key) async {
    final box = await Hive.openBox(_boxName);
    return box.get(key, defaultValue: 0) as int;
  }

  @override
  Future<void> saveBest(String key, int value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(key, value);
  }

  @override
  Future<void> saveGame(Map<String, dynamic> data) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_savedGameKey, data);
  }

  @override
  Future<Map<String, dynamic>?> loadGame() async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(_savedGameKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<void> clearGame() async {
    final box = await Hive.openBox(_boxName);
    await box.delete(_savedGameKey);
  }
}
