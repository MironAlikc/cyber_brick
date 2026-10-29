import 'dart:async';
import 'dart:math';

import 'package:cyber_brick/core/ach_stats.dart';
import 'package:cyber_brick/features/data/domain/entities/game_mode.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'reward_local_data_source.dart';

/// Статистика и достижения. Награда в рубинах начисляется при открытии.
class AchievementsLocalDataSource {
  static const String _boxName = 'cyber_brick_box';
  static const String _statsKey = 'ach_stats';
  static const String _unlockedKey = 'ach_unlocked';

  static Future<void> _queue = Future.value();

  static Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Map<String, dynamic> _readStats(Box box) => Map<String, dynamic>.from(
    box.get(_statsKey, defaultValue: <String, dynamic>{}) as Map,
  );

  Set<String> _readUnlocked(Box box) => {
    ...(box.get(_unlockedKey, defaultValue: <dynamic>[]) as List)
        .cast<String>(),
  };

  Future<Set<String>> getUnlocked() => _enqueue(() async {
    final box = await Hive.openBox(_boxName);
    return _readUnlocked(box);
  });

  /// Обновляет статистику и возвращает только что открытые достижения.
  Future<List<AchievementDef>> report({
    int lines = 0,
    bool tetris = false,
    int games = 0,
    int? score,
    int? level,
    GameMode? mode,
    bool sprintDone = false,
    int? streak,
  }) => _enqueue(() async {
    try {
      final box = await Hive.openBox(_boxName);
      final m = _readStats(box);
      int geti(String k) => (m[k] as int?) ?? 0;

      m['totalLines'] = geti('totalLines') + lines;
      if (tetris) m['tetrises'] = geti('tetrises') + 1;
      m['totalGames'] = geti('totalGames') + games;
      if (score != null) {
        m['bestScore'] = max(geti('bestScore'), score);
        if (mode == GameMode.ultra) {
          m['bestUltra'] = max(geti('bestUltra'), score);
        }
      }
      if (level != null) m['maxLevel'] = max(geti('maxLevel'), level);
      if (sprintDone) m['sprintDone'] = true;
      if (streak != null) m['maxStreak'] = max(geti('maxStreak'), streak);
      await box.put(_statsKey, m);

      final stats = AchStats.fromMap(m);
      final unlocked = _readUnlocked(box);
      final newly = <AchievementDef>[
        for (final a in kAchievements)
          if (!unlocked.contains(a.id) && a.test(stats)) a,
      ];

      if (newly.isNotEmpty) {
        unlocked.addAll(newly.map((a) => a.id));
        await box.put(_unlockedKey, unlocked.toList());
        final reward = newly.fold<int>(0, (sum, a) => sum + a.reward);
        await RewardLocalDataSource().addRubies(reward);
      }
      return newly;
    } catch (_) {
      return <AchievementDef>[];
    }
  });
}
