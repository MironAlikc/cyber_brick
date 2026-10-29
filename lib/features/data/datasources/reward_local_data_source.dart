import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

/// Состояние ежедневной награды.
class DailyRewardInfo {
  final bool canClaim;

  /// День серии в цикле 1…7 (для которого сейчас показывается награда).
  final int day;

  /// Сколько рубинов даёт этот день.
  final int amount;

  /// Сколько дней подряд (с учётом сегодняшнего).
  final int streak;

  const DailyRewardInfo({
    required this.canClaim,
    required this.day,
    required this.amount,
    required this.streak,
  });
}

class ClaimResult {
  final int total;
  final int amount;

  const ClaimResult({required this.total, required this.amount});
}

/// Рубины и ежедневная награда с серией дней.
class RewardLocalDataSource {
  /// Награда по дням серии. После 7-го дня цикл начинается заново.
  static const List<int> dailyRewards = [3, 3, 5, 5, 8, 8, 15];

  static const String _boxName = 'cyber_brick_box';
  static const String _rubiesKey = 'rubies';
  static const String _lastClaimKey = 'last_claim_date';
  static const String _streakKey = 'claim_streak';

  Future<Box> get _box => Hive.openBox(_boxName);

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _today() => _key(DateTime.now());

  String _yesterday() {
    final n = DateTime.now();
    return _key(DateTime(n.year, n.month, n.day - 1));
  }

  Future<int> getRubies() async =>
      (await _box).get(_rubiesKey, defaultValue: 0) as int;

  Future<int> addRubies(int amount) async {
    final box = await _box;
    final total = (box.get(_rubiesKey, defaultValue: 0) as int) + amount;
    await box.put(_rubiesKey, total);
    return total;
  }

  /// Списывает рубины. Возвращает false, если не хватает.
  Future<bool> spendRubies(int amount) async {
    final box = await _box;
    final current = box.get(_rubiesKey, defaultValue: 0) as int;
    if (current < amount) return false;
    await box.put(_rubiesKey, current - amount);
    return true;
  }

  Future<DailyRewardInfo> getDailyInfo() async {
    final box = await _box;
    final last = box.get(_lastClaimKey) as String?;
    final stored = max(box.get(_streakKey, defaultValue: 0) as int, 0);

    final claimedToday = last == _today();
    final int streak = claimedToday
        ? max(stored, 1)
        : (last == _yesterday() ? stored + 1 : 1);

    final day = (streak - 1) % dailyRewards.length + 1;

    return DailyRewardInfo(
      canClaim: !claimedToday,
      day: day,
      amount: dailyRewards[day - 1],
      streak: streak,
    );
  }

  Future<bool> canClaimDaily() async => (await getDailyInfo()).canClaim;

  /// Начисляет награду за сегодня. Возвращает null, если уже получена.
  Future<ClaimResult?> claimDaily() async {
    final info = await getDailyInfo();
    if (!info.canClaim) return null;

    final box = await _box;
    final total = (box.get(_rubiesKey, defaultValue: 0) as int) + info.amount;
    await box.put(_rubiesKey, total);
    await box.put(_streakKey, info.streak);
    await box.put(_lastClaimKey, _today());

    return ClaimResult(total: total, amount: info.amount);
  }
}
