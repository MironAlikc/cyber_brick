import 'package:cyber_brick/core/ach_stats.dart';
import 'package:cyber_brick/features/data/domain/entities/daily_task.dart';
import 'package:cyber_brick/features/data/domain/entities/position.dart';
import 'package:cyber_brick/features/data/domain/entities/tetromino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tetromino.fromType создаёт 4 клетки для каждой фигуры', () {
    for (final type in TetrominoType.values) {
      final piece = Tetromino.fromType(type);
      expect(piece.positions.length, 4);
    }
  });

  test('Tetromino сохраняется и восстанавливается через JSON', () {
    final piece = Tetromino.fromType(TetrominoType.t)
      ..positions = const [
        Position(1, 2),
        Position(2, 2),
        Position(3, 2),
        Position(2, 3),
      ];

    final restored = Tetromino.fromJson(piece.toJson());

    expect(restored.type, TetrominoType.t);
    expect(restored.positions.map((p) => [p.x, p.y]).toList(), [
      [1, 2],
      [2, 2],
      [3, 2],
      [2, 3],
    ]);
  });

  test(
    'DailyTask: claimable только после выполнения и до получения награды',
    () {
      const def = DailyTaskDef(TaskId.lines, 'CLEAR 10 LINES', 10, 2);

      expect(
        const DailyTask(def: def, progress: 4, claimed: false).claimable,
        false,
      );
      expect(
        const DailyTask(def: def, progress: 10, claimed: false).claimable,
        true,
      );
      expect(
        const DailyTask(def: def, progress: 12, claimed: true).claimable,
        false,
      );
    },
  );

  test('Достижения открываются по статистике', () {
    AchievementDef find(String id) =>
        kAchievements.firstWhere((a) => a.id == id);

    const empty = AchStats();
    expect(find('first_line').test(empty), false);

    const played = AchStats(totalLines: 1, tetrises: 1, totalGames: 10);
    expect(find('first_line').test(played), true);
    expect(find('tetris').test(played), true);
    expect(find('games_10').test(played), true);
    expect(find('lines_100').test(played), false);

    expect(find('sprint').test(const AchStats(sprintDone: true)), true);
    expect(find('streak_7').test(const AchStats(maxStreak: 7)), true);
  });

  test('У каждого достижения уникальный id', () {
    final ids = kAchievements.map((a) => a.id).toSet();
    expect(ids.length, kAchievements.length);
  });
}
