import 'dart:math' as math;

import 'package:cyber_brick/core/ach_stats.dart';
import 'package:cyber_brick/core/app_settings.dart';
import 'package:cyber_brick/core/audio_service.dart';
import 'package:cyber_brick/core/haptics.dart';
import 'package:cyber_brick/core/retro_theme.dart';
import 'package:cyber_brick/core/retro_ui.dart';
import 'package:flutter/material.dart';

import '../../data/datasources/achievements_local_data_source.dart';
import '../../data/datasources/daily_tasks_local_data_source.dart';
import '../../data/datasources/game_local_data_source.dart';
import '../../data/datasources/reward_local_data_source.dart';
import '../../data/domain/entities/daily_task.dart';
import '../../data/domain/entities/game_mode.dart';
import 'game_screen.dart';

enum _Page { menu, modes, reward, tasks, trophies, shop, settings }

/// Главное меню. Если награда за день ещё не получена — стартует
/// сразу с окна Daily Reward.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _rewards = RewardLocalDataSource();
  final _tasksDs = DailyTasksLocalDataSource();
  final _game = GameLocalDataSourceImpl();
  final _ach = AchievementsLocalDataSource();

  _Page _page = _Page.menu;
  bool _loaded = false;
  bool _hasSave = false;
  int _rubies = 0;
  int _highScore = 250;
  List<DailyTask> _tasks = const [];
  Set<String> _unlocked = {};
  int _bestSprintMs = 0;
  int _bestUltra = 0;
  DailyRewardInfo _info = const DailyRewardInfo(
    canClaim: false,
    day: 1,
    amount: 3,
    streak: 0,
  );

  bool get _tasksClaimable => _tasks.any((t) => t.claimable);

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    final info = await _rewards.getDailyInfo();
    final rubies = await _rewards.getRubies();
    final tasks = await _tasksDs.getTasks();
    final hasSave = await _game.loadGame() != null;
    final high = await _game.getHighScore();
    final unlocked = await _ach.getUnlocked();
    final bestSprint = await _game.getBest(kBestSprintKey);
    final bestUltra = await _game.getBest(kBestUltraKey);
    if (!mounted) return;
    setState(() {
      _info = info;
      _rubies = rubies;
      _tasks = tasks;
      _hasSave = hasSave;
      _highScore = math.max(high, 250);
      _unlocked = unlocked;
      _bestSprintMs = bestSprint;
      _bestUltra = bestUltra;
      if (initial && info.canClaim) _page = _Page.reward;
      _loaded = true;
    });
  }

  Future<void> _claim() async {
    final result = await _rewards.claimDaily();
    if (result == null) return;
    Haptics.heavy();
    AudioService.instance.play(Sfx.claim);
    final newly = await _ach.report(streak: _info.streak);
    if (newly.isNotEmpty) {
      _toast('🏆 ${newly.map((a) => '${a.title} +${a.reward}').join('  •  ')}');
    }
    await _load();
  }

  Future<void> _claimTask(DailyTask task) async {
    final reward = await _tasksDs.claim(task.def.id);
    if (reward > 0) {
      Haptics.heavy();
      AudioService.instance.play(Sfx.claim);
    }
    await _load();
  }

  Future<void> _openGame({
    required bool resume,
    GameMode mode = GameMode.marathon,
  }) async {
    AudioService.instance.play(Sfx.click);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(resume: resume, mode: mode),
      ),
    );
    if (mounted) _load();
  }

  void _go(_Page page) => setState(() => _page = page);

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onTheme(RetroTheme theme) async {
    if (AppSettings.ownedThemes.contains(theme.id)) {
      await AppSettings.setTheme(theme.id);
      AudioService.instance.play(Sfx.click);
      if (mounted) setState(() {});
      return;
    }

    final ok = await _rewards.spendRubies(theme.price);
    if (!ok) {
      _toast('Не хватает рубинов');
      return;
    }
    await AppSettings.unlockTheme(theme.id);
    await AppSettings.setTheme(theme.id);
    Haptics.heavy();
    AudioService.instance.play(Sfx.claim);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RetroShell(
      controls: [
        ..._buttons(),
        if (_loaded && _page == _Page.shop) ..._shopSwatches(),
      ],
      children: [if (_loaded) ..._pageChildren()],
    );
  }

  // ───────────────────────── Страницы ─────────────────────────

  List<Widget> _pageChildren() {
    switch (_page) {
      case _Page.menu:
        return _menuPage();
      case _Page.modes:
        return _modesPage();
      case _Page.reward:
        return _rewardPage();
      case _Page.tasks:
        return _tasksPage();
      case _Page.trophies:
        return _trophiesPage();
      case _Page.shop:
        return _shopPage();
      case _Page.settings:
        return _settingsPage();
    }
  }

  Widget _closeButton() => Positioned(
    left: 479,
    top: 148,
    child: RetroCloseButton(onTap: () => _go(_Page.menu)),
  );

  Widget _rubiesLabel() => Positioned(
    left: 194.5,
    top: 790,
    child: LcdText('RUBIES $_rubies', width: 200, height: 26),
  );

  List<Widget> _menuPage() {
    final rows = <_RowData>[
      if (_hasSave) _RowData('CONTINUE', () => _openGame(resume: true)),
      _RowData('NEW GAME', () => _go(_Page.modes)),
      _RowData(
        _info.canClaim ? 'DAILY REWARD!' : 'DAILY REWARD',
        () => _go(_Page.reward),
      ),
      _RowData(
        _tasksClaimable ? 'DAILY TASKS!' : 'DAILY TASKS',
        () => _go(_Page.tasks),
      ),
      _RowData('SETTINGS', () => _go(_Page.settings)),
    ];

    return [
      const Positioned(
        left: 114.5,
        top: 190,
        child: LcdText('CYBER BRICK', width: 360, height: 64),
      ),
      Positioned(
        left: 174.5,
        top: 272,
        child: LcdText('HI-SCORE $_highScore', width: 240, height: 26),
      ),
      for (var i = 0; i < rows.length; i++)
        Positioned(
          left: 153,
          top: 330 + i * 80.0,
          child: _LcdButton(rows[i].label, rows[i].onTap),
        ),
      _rubiesLabel(),
    ];
  }

  List<Widget> _rewardPage() {
    final label = _info.canClaim
        ? '+${_info.amount} RUBIES'
        : 'COME BACK TOMORROW';
    final filled = _info.canClaim ? _info.day - 1 : _info.day;

    return [
      _closeButton(),
      const Positioned(
        left: 152,
        top: 218,
        child: LcdText('DAILY REWARD', width: 286, height: 42),
      ),
      const Positioned(
        left: 122,
        top: 289,
        child: LcdText('COME BACK EVERY DAY TO', width: 345, height: 29),
      ),
      const Positioned(
        left: 146,
        top: 333,
        child: LcdText('COLLECT FREE RUBIES!', width: 298, height: 29),
      ),
      const Positioned(
        left: 175,
        top: 398,
        child: CustomPaint(size: Size(240, 252), painter: _GiftPainter()),
      ),

      // Серия дней: 7 квадратиков, текущий день выделен рамкой.
      Positioned(
        left: 193.5,
        top: 668,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < RewardLocalDataSource.dailyRewards.length; i++)
              Container(
                margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                width: 22,
                height: 16,
                decoration: BoxDecoration(
                  color: i < filled ? RetroColors.ink : Colors.transparent,
                  border: Border.all(
                    color: RetroColors.ink,
                    width: (_info.canClaim && i == _info.day - 1) ? 4 : 2,
                  ),
                ),
              ),
          ],
        ),
      ),

      Positioned(
        left: 153,
        top: 702,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _claim,
          child: Container(
            width: 283,
            height: 68,
            alignment: Alignment.center,
            color: RetroColors.darkButton,
            child: LcdText(
              label,
              width: _info.canClaim ? math.min(label.length * 14.4, 240) : 240,
              height: 26,
              color: _info.canClaim
                  ? RetroColors.darkButtonText
                  : RetroColors.darkButtonText.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _tasksPage() {
    return [
      _closeButton(),
      const Positioned(
        left: 144.5,
        top: 218,
        child: LcdText('DAILY TASKS', width: 300, height: 42),
      ),
      for (var i = 0; i < _tasks.length; i++)
        Positioned(
          left: 74,
          top: 290 + i * 140.0,
          child: _TaskCard(
            task: _tasks[i],
            onClaim: () => _claimTask(_tasks[i]),
          ),
        ),
      _rubiesLabel(),
    ];
  }

  List<Widget> _modesPage() {
    final modes = <_RowData>[
      _RowData(
        'MARATHON',
        () => _openGame(resume: false, mode: GameMode.marathon),
      ),
      _RowData(
        'SPRINT: $kSprintLines LINES',
        () => _openGame(resume: false, mode: GameMode.sprint),
      ),
      _RowData(
        'ULTRA: ${kUltraSeconds ~/ 60} MIN',
        () => _openGame(resume: false, mode: GameMode.ultra),
      ),
    ];

    return [
      _closeButton(),
      const Positioned(
        left: 129.5,
        top: 218,
        child: LcdText('SELECT MODE', width: 330, height: 42),
      ),
      for (var i = 0; i < modes.length; i++)
        Positioned(
          left: 153,
          top: 335 + i * 84.0,
          child: _LcdButton(modes[i].label, modes[i].onTap),
        ),
      const Positioned(
        left: 94.5,
        top: 610,
        child: LcdText(
          'SPRINT: FASTEST TIME  /  ULTRA: BEST SCORE',
          width: 400,
          height: 18,
        ),
      ),
    ];
  }

  Widget _trophyRow(AchievementDef a) {
    final done = _unlocked.contains(a.id);
    final color = done
        ? RetroColors.ink
        : RetroColors.ink.withValues(alpha: 0.5);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RetroColors.line, width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LcdText(
                  a.title,
                  width: 280,
                  height: 22,
                  alignment: Alignment.centerLeft,
                  color: color,
                ),
                const SizedBox(height: 4),
                LcdText(
                  a.description,
                  width: 280,
                  height: 14,
                  alignment: Alignment.centerLeft,
                  color: color,
                ),
              ],
            ),
          ),
          LcdText(
            done ? 'DONE' : '+${a.reward}',
            width: 70,
            height: 20,
            alignment: Alignment.centerRight,
            color: color,
          ),
        ],
      ),
    );
  }

  List<Widget> _trophiesPage() {
    final sprint = _bestSprintMs == 0 ? '--' : formatMsText(_bestSprintMs);

    return [
      _closeButton(),
      const Positioned(
        left: 174.5,
        top: 218,
        child: LcdText('TROPHIES', width: 240, height: 42),
      ),
      Positioned(
        left: 144.5,
        top: 272,
        child: LcdText('MARATHON $_highScore', width: 300, height: 22),
      ),
      Positioned(
        left: 144.5,
        top: 300,
        child: LcdText('SPRINT $sprint', width: 300, height: 22),
      ),
      Positioned(
        left: 144.5,
        top: 328,
        child: LcdText('ULTRA $_bestUltra', width: 300, height: 22),
      ),
      Positioned(
        left: 63,
        top: 372,
        width: 463,
        height: 408,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [for (final a in kAchievements) _trophyRow(a)],
        ),
      ),
    ];
  }

  /// Образцы цветов тем рисуются вне ThemedLcd, чтобы фильтр не искажал их.
  List<Widget> _shopSwatches() {
    return [
      for (var i = 0; i < kThemes.length; i++)
        Positioned(
          left: 93,
          top: 292 + i * 90.0 + 18,
          child: IgnorePointer(
            child: Row(
              children: [
                Container(width: 22, height: 40, color: kThemes[i].swatchDark),
                Container(width: 22, height: 40, color: kThemes[i].swatchLight),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _shopPage() {
    return [
      _closeButton(),
      const Positioned(
        left: 174.5,
        top: 218,
        child: LcdText('SHOP', width: 240, height: 42),
      ),
      for (var i = 0; i < kThemes.length; i++)
        Positioned(
          left: 74,
          top: 292 + i * 90.0,
          child: _ThemeCard(
            theme: kThemes[i],
            owned: AppSettings.ownedThemes.contains(kThemes[i].id),
            equipped: AppSettings.themeId == kThemes[i].id,
            onTap: () => _onTheme(kThemes[i]),
          ),
        ),
      _rubiesLabel(),
    ];
  }

  List<Widget> _settingsPage() {
    final toggles = <_ToggleData>[
      _ToggleData('GESTURES', AppSettings.gesturesOn, AppSettings.setGestures),
      _ToggleData(
        'VIBRATION',
        AppSettings.vibrationOn,
        AppSettings.setVibration,
      ),
      _ToggleData('MUSIC', AppSettings.musicOn, (v) async {
        await AppSettings.setMusic(v);
        await AudioService.instance.syncMusic();
      }),
      _ToggleData('SOUND', AppSettings.soundOn, AppSettings.setSound),
    ];

    return [
      _closeButton(),
      const Positioned(
        left: 174.5,
        top: 218,
        child: LcdText('SETTINGS', width: 240, height: 42),
      ),
      for (var i = 0; i < toggles.length; i++)
        Positioned(
          left: 153,
          top: 335 + i * 84.0,
          child: _LcdButton(
            '${toggles[i].label}: ${toggles[i].value ? 'ON' : 'OFF'}',
            () async {
              Haptics.selection();
              await toggles[i].set(!toggles[i].value);
              if (mounted) setState(() {});
            },
          ),
        ),
    ];
  }

  // ───────────────────────── Нижние кнопки ─────────────────────────

  List<Widget> _buttons() {
    return [
      Positioned(
        left: 33,
        top: 938,
        child: ArcadeButton(
          size: 86,
          kind: ArcadeKind.yellow,
          icon: Icon(
            AppSettings.musicOn ? Icons.music_note : Icons.music_off,
            size: 50,
            color: kOrangeIcon,
          ),
          onPressed: () async {
            await AppSettings.setMusic(!AppSettings.musicOn);
            await AudioService.instance.syncMusic();
            if (mounted) setState(() {});
          },
        ),
      ),
      Positioned(
        left: 193,
        top: 938,
        child: ArcadeButton(
          size: 86,
          kind: ArcadeKind.yellow,
          icon: Icon(
            AppSettings.soundOn ? Icons.volume_up : Icons.volume_off,
            size: 50,
            color: kOrangeIcon,
          ),
          onPressed: () async {
            await AppSettings.setSound(!AppSettings.soundOn);
            AudioService.instance.play(Sfx.click);
            if (mounted) setState(() {});
          },
        ),
      ),
      Positioned(
        left: 113,
        top: 1019,
        child: ArcadeButton(
          size: 86,
          kind: ArcadeKind.yellow,
          icon: const CrownIcon(),
          onPressed: () => _go(_Page.trophies),
        ),
      ),
      Positioned(
        left: 347,
        top: 995,
        child: ArcadeButton(
          size: 110,
          kind: ArcadeKind.blue,
          icon: const Icon(Icons.play_arrow, size: 78, color: kBlueIcon),
          onPressed: () => _openGame(resume: _hasSave),
        ),
      ),
      Positioned(
        left: 468,
        top: 937,
        child: ArcadeButton(
          size: 88,
          kind: ArcadeKind.blue,
          icon: const Icon(Icons.shopping_cart, size: 50, color: kBlueIcon),
          onPressed: () => _go(_Page.shop),
        ),
      ),
    ];
  }
}

class _RowData {
  final String label;
  final VoidCallback onTap;

  _RowData(this.label, this.onTap);
}

class _ToggleData {
  final String label;
  final bool value;
  final Future<void> Function(bool) set;

  _ToggleData(this.label, this.value, this.set);
}

/// Тёмная LCD-кнопка 283 × 60.
class _LcdButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LcdButton(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.selection();
        AudioService.instance.play(Sfx.click);
        onTap();
      },
      child: Container(
        width: 283,
        height: 60,
        alignment: Alignment.center,
        color: RetroColors.darkButton,
        child: LcdText(
          label,
          width: math.min(label.length * 16.0, 250),
          height: 26,
          color: RetroColors.darkButtonText,
        ),
      ),
    );
  }
}

/// Время m:ss.t для рекордов.
String formatMsText(int ms) {
  final secs = (ms % 60000) / 1000;
  return '${ms ~/ 60000}:${secs.toStringAsFixed(1).padLeft(4, '0')}';
}

/// Карточка темы 440 × 76: образец цветов, название и статус.
class _ThemeCard extends StatelessWidget {
  final RetroTheme theme;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = equipped
        ? 'EQUIPPED'
        : (owned ? 'OWNED' : '${theme.price} RUBIES');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 440,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: RetroColors.ink, width: equipped ? 5 : 3),
        ),
        child: Row(
          children: [
            // Место под образец цветов (он рисуется поверх, вне цветового фильтра).
            const SizedBox(width: 60),
            LcdText(
              theme.name,
              width: 150,
              height: 24,
              alignment: Alignment.centerLeft,
            ),
            const Spacer(),
            LcdText(
              status,
              width: 140,
              height: 20,
              alignment: Alignment.centerRight,
              color: RetroColors.ink.withValues(alpha: owned ? 1 : 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка задания 440 × 120: название, прогресс-бар, счётчик и кнопка.
class _TaskCard extends StatelessWidget {
  final DailyTask task;
  final VoidCallback onClaim;

  const _TaskCard({required this.task, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final progress = math.min(task.progress, task.def.goal);
    final fraction = progress / task.def.goal;

    return Container(
      width: 440,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: RetroColors.ink, width: 3),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 12,
            child: LcdText(
              task.def.title,
              width: 290,
              height: 24,
              alignment: Alignment.centerLeft,
            ),
          ),
          Positioned(
            left: 16,
            top: 48,
            child: Container(
              width: 402,
              height: 20,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border.all(color: RetroColors.ink, width: 2),
              ),
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: Container(color: RetroColors.ink),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 80,
            child: LcdText(
              '$progress/${task.def.goal}',
              width: 130,
              height: 22,
              alignment: Alignment.centerLeft,
            ),
          ),
          Positioned(right: 14, top: 74, child: _action()),
        ],
      ),
    );
  }

  Widget _action() {
    if (task.claimable) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClaim,
        child: Container(
          width: 150,
          height: 34,
          alignment: Alignment.center,
          color: RetroColors.darkButton,
          child: LcdText(
            'CLAIM +${task.def.reward}',
            width: 120,
            height: 20,
            color: RetroColors.darkButtonText,
          ),
        ),
      );
    }

    return SizedBox(
      width: 150,
      height: 34,
      child: LcdText(
        task.claimed ? 'DONE' : 'REWARD +${task.def.reward}',
        width: 150,
        height: 20,
        alignment: Alignment.centerRight,
        color: RetroColors.ink.withValues(alpha: task.claimed ? 0.45 : 0.8),
      ),
    );
  }
}

/// Контурный подарок с бантом, 240 × 252.
class _GiftPainter extends CustomPainter {
  const _GiftPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.miter
      ..color = RetroColors.ink;

    canvas.drawRect(const Rect.fromLTWH(1, 69, 237, 49), line);
    canvas.drawRect(const Rect.fromLTWH(12, 118, 215, 131), line);

    canvas.drawLine(const Offset(95, 69), const Offset(95, 249), line);
    canvas.drawLine(const Offset(143, 69), const Offset(143, 249), line);

    canvas.drawArc(
      const Rect.fromLTWH(95, 47, 48, 44),
      math.pi,
      math.pi,
      false,
      line,
    );

    final outer = Path()
      ..moveTo(98, 62)
      ..cubicTo(86, 20, 40, -2, 14, 26)
      ..cubicTo(8, 46, 52, 64, 98, 66);
    final inner = Path()
      ..moveTo(92, 58)
      ..cubicTo(76, 32, 46, 22, 30, 34)
      ..cubicTo(40, 48, 66, 56, 92, 58);

    canvas.drawPath(outer, line);
    canvas.drawPath(inner, line);

    canvas.save();
    canvas.translate(238, 0);
    canvas.scale(-1, 1);
    canvas.drawPath(outer, line);
    canvas.drawPath(inner, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GiftPainter old) => false;
}
