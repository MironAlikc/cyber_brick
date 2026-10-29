enum TaskId { lines, games, score }

/// Описание задания (одинаково для всех дней).
class DailyTaskDef {
  final TaskId id;
  final String title;
  final int goal;
  final int reward;

  const DailyTaskDef(this.id, this.title, this.goal, this.reward);
}

const List<DailyTaskDef> kDailyTaskDefs = [
  DailyTaskDef(TaskId.lines, 'CLEAR 10 LINES', 10, 2),
  DailyTaskDef(TaskId.games, 'PLAY 3 GAMES', 3, 1),
  DailyTaskDef(TaskId.score, 'SCORE 1000', 1000, 3),
];

/// Состояние задания на сегодня.
class DailyTask {
  final DailyTaskDef def;
  final int progress;
  final bool claimed;

  const DailyTask({
    required this.def,
    required this.progress,
    required this.claimed,
  });

  bool get completed => progress >= def.goal;
  bool get claimable => completed && !claimed;
}
