/// Накопленная статистика игрока (по ней открываются достижения).
class AchStats {
  final int totalLines;
  final int totalGames;
  final int bestScore;
  final int maxLevel;
  final int tetrises;
  final int bestUltra;
  final int maxStreak;
  final bool sprintDone;

  const AchStats({
    this.totalLines = 0,
    this.totalGames = 0,
    this.bestScore = 0,
    this.maxLevel = 0,
    this.tetrises = 0,
    this.bestUltra = 0,
    this.maxStreak = 0,
    this.sprintDone = false,
  });

  factory AchStats.fromMap(Map<String, dynamic> m) => AchStats(
    totalLines: (m['totalLines'] as int?) ?? 0,
    totalGames: (m['totalGames'] as int?) ?? 0,
    bestScore: (m['bestScore'] as int?) ?? 0,
    maxLevel: (m['maxLevel'] as int?) ?? 0,
    tetrises: (m['tetrises'] as int?) ?? 0,
    bestUltra: (m['bestUltra'] as int?) ?? 0,
    maxStreak: (m['maxStreak'] as int?) ?? 0,
    sprintDone: (m['sprintDone'] as bool?) ?? false,
  );
}

class AchievementDef {
  final String id;
  final String title;
  final String description;
  final int reward;
  final bool Function(AchStats) test;

  const AchievementDef(
    this.id,
    this.title,
    this.description,
    this.reward,
    this.test,
  );
}

final List<AchievementDef> kAchievements = [
  AchievementDef(
    'first_line',
    'FIRST LINE',
    'CLEAR YOUR FIRST LINE',
    1,
    (s) => s.totalLines >= 1,
  ),
  AchievementDef(
    'tetris',
    'TETRIS',
    'CLEAR 4 LINES AT ONCE',
    3,
    (s) => s.tetrises >= 1,
  ),
  AchievementDef(
    'score_5000',
    'HIGH SCORE',
    'SCORE 5000 IN ONE GAME',
    3,
    (s) => s.bestScore >= 5000,
  ),
  AchievementDef(
    'level_5',
    'SPEEDSTER',
    'REACH LEVEL 5',
    3,
    (s) => s.maxLevel >= 5,
  ),
  AchievementDef(
    'lines_100',
    'LINE MASTER',
    'CLEAR 100 LINES IN TOTAL',
    5,
    (s) => s.totalLines >= 100,
  ),
  AchievementDef(
    'games_10',
    'REGULAR',
    'PLAY 10 GAMES',
    2,
    (s) => s.totalGames >= 10,
  ),
  AchievementDef(
    'sprint',
    'SPRINTER',
    'FINISH A SPRINT',
    5,
    (s) => s.sprintDone,
  ),
  AchievementDef(
    'ultra_3000',
    'ULTRA RUNNER',
    'SCORE 3000 IN ULTRA',
    4,
    (s) => s.bestUltra >= 3000,
  ),
  AchievementDef(
    'streak_7',
    'WEEK STREAK',
    'CLAIM REWARD 7 DAYS IN A ROW',
    5,
    (s) => s.maxStreak >= 7,
  ),
];
