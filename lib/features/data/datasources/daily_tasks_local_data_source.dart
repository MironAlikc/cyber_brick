import 'dart:async';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../domain/entities/daily_task.dart';
import 'reward_local_data_source.dart';

/// Ежедневные задания: прогресс обнуляется с началом нового дня.
class DailyTasksLocalDataSource {
  static const String _boxName = 'cyber_brick_box';
  static const String _stateKey = 'daily_tasks';

  // Все операции идут по очереди, чтобы параллельные записи не затирали друг друга.
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

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _readState(Box box) {
    final raw = box.get(_stateKey);
    if (raw is Map && raw['day'] == _today()) {
      return {
        'day': raw['day'],
        'progress': Map<String, dynamic>.from(raw['progress'] as Map),
        'claimed': Map<String, dynamic>.from(raw['claimed'] as Map),
      };
    }
    return {
      'day': _today(),
      'progress': <String, dynamic>{},
      'claimed': <String, dynamic>{},
    };
  }

  Future<List<DailyTask>> getTasks() => _enqueue(() async {
    final box = await Hive.openBox(_boxName);
    final state = _readState(box);
    final progress = state['progress'] as Map<String, dynamic>;
    final claimed = state['claimed'] as Map<String, dynamic>;

    return [
      for (final def in kDailyTaskDefs)
        DailyTask(
          def: def,
          progress: (progress[def.id.name] as int?) ?? 0,
          claimed: (claimed[def.id.name] as bool?) ?? false,
        ),
    ];
  });

  /// Прибавляет прогресс (линии, партии). Ошибки не пробрасываются.
  Future<void> addProgress(TaskId id, int amount) => _enqueue(() async {
    try {
      final box = await Hive.openBox(_boxName);
      final state = _readState(box);
      final progress = state['progress'] as Map<String, dynamic>;
      progress[id.name] = ((progress[id.name] as int?) ?? 0) + amount;
      await box.put(_stateKey, state);
    } catch (_) {}
  });

  /// Запоминает лучший счёт за день.
  Future<void> reportScore(int score) => _enqueue(() async {
    try {
      final box = await Hive.openBox(_boxName);
      final state = _readState(box);
      final progress = state['progress'] as Map<String, dynamic>;
      final current = (progress[TaskId.score.name] as int?) ?? 0;
      progress[TaskId.score.name] = max(current, score);
      await box.put(_stateKey, state);
    } catch (_) {}
  });

  /// Забирает награду за выполненное задание. Возвращает число рубинов (0 — нельзя).
  Future<int> claim(TaskId id) => _enqueue(() async {
    final box = await Hive.openBox(_boxName);
    final state = _readState(box);
    final progress = state['progress'] as Map<String, dynamic>;
    final claimed = state['claimed'] as Map<String, dynamic>;

    final def = kDailyTaskDefs.firstWhere((d) => d.id == id);
    final done = ((progress[id.name] as int?) ?? 0) >= def.goal;
    final already = (claimed[id.name] as bool?) ?? false;
    if (!done || already) return 0;

    claimed[id.name] = true;
    await box.put(_stateKey, state);
    await RewardLocalDataSource().addRubies(def.reward);
    return def.reward;
  });
}
