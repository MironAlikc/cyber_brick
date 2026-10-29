import 'dart:math' as math;

import 'package:cyber_brick/core/app_settings.dart';
import 'package:cyber_brick/core/haptics.dart';
import 'package:cyber_brick/core/retro_theme.dart';
import 'package:cyber_brick/core/retro_ui.dart';
import 'package:cyber_brick/features/data/domain/entities/game_mode.dart';
import 'package:cyber_brick/features/data/domain/entities/position.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/achievements_local_data_source.dart';
import '../../data/datasources/daily_tasks_local_data_source.dart';
import '../../data/datasources/game_local_data_source.dart';
import '../cubit/game_cubit.dart';
import '../cubit/game_state.dart';

/// Вся вёрстка сделана в «дизайн-пикселях» эталонного скриншота 589 × 1280
/// и масштабируется через FittedBox — на любом экране выглядит одинаково.
const double _designW = 589;
const double _designH = 1280;

/// m:ss
String formatClock(int ms) =>
    '${ms ~/ 60000}:${((ms % 60000) ~/ 1000).toString().padLeft(2, '0')}';

/// m:ss.t
String formatMs(int ms) {
  final secs = (ms % 60000) / 1000;
  return '${ms ~/ 60000}:${secs.toStringAsFixed(1).padLeft(4, '0')}';
}

class GameScreen extends StatelessWidget {
  /// true — продолжить сохранённую партию (если есть), false — новая игра.
  final bool resume;

  /// Режим новой партии (при продолжении берётся из сохранения).
  final GameMode mode;

  const GameScreen({
    super.key,
    this.resume = true,
    this.mode = GameMode.marathon,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameCubit(
        GameLocalDataSourceImpl(),
        tasks: DailyTasksLocalDataSource(),
        achievements: AchievementsLocalDataSource(),
      )..startOrResume(resume: resume, mode: mode),
      child: const Scaffold(
        backgroundColor: RetroColors.page,
        body: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _designW,
              height: _designH,
              child: _LifecyclePause(child: _GameView()),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameView extends StatelessWidget {
  const _GameView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listenWhen: (p, c) =>
          c.unlocked.isNotEmpty && !identical(p.unlocked, c.unlocked),
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text('🏆 ${state.unlocked.join('  •  ')}'),
            ),
          );
      },
      child: BlocConsumer<GameCubit, GameState>(
        listenWhen: (p, c) =>
            p.status != c.status &&
            (c.status == GameStatus.gameOver ||
                c.status == GameStatus.completed),
        listener: (context, state) {
          Haptics.vibrate();
          final isOver = state.status == GameStatus.gameOver;
          final isSprint = state.mode == GameMode.sprint;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: RetroColors.lcd,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
                side: const BorderSide(color: RetroColors.lcdBorder, width: 2),
              ),
              title: Text(
                isOver ? 'GAME OVER' : (isSprint ? 'COMPLETE' : 'TIME UP'),
                style: const TextStyle(
                  fontFamily: kPixelFontFamily,
                  fontSize: 16,
                  color: RetroColors.label,
                ),
              ),
              content: Text(
                (!isOver && isSprint)
                    ? 'Время: ${formatMs(state.elapsedMs)}'
                    : 'Ваш результат: ${state.score}',
                style: const TextStyle(color: RetroColors.label),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Haptics.selection();
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Меню',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Haptics.medium();
                    Navigator.of(dialogContext).pop();
                    context.read<GameCubit>().restart();
                  },
                  child: const Text(
                    'Заново',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        builder: (context, state) {
          final cubit = context.read<GameCubit>();

          return Stack(
            children: [
              // Заголовок
              const Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: Text(
                  'BRICK CLASSIC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: RetroColors.title,
                    height: 1.1,
                  ),
                ),
              ),

              // Корпус
              Positioned(
                left: 27,
                top: 110,
                width: 535,
                height: 776,
                child: ThemedLcd(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: RetroColors.frame,
                      border: Border(
                        top: BorderSide(
                          color: RetroColors.frameLight,
                          width: 3,
                        ),
                        left: BorderSide(
                          color: RetroColors.frameLight,
                          width: 3,
                        ),
                        right: BorderSide(
                          color: RetroColors.frameDark,
                          width: 3,
                        ),
                        bottom: BorderSide(
                          color: RetroColors.frameDark,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: RetroColors.lcd,
                        border: Border.all(
                          color: RetroColors.lcdBorder,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          _BoardView(state: state, cubit: cubit),
                          Container(width: 2, color: RetroColors.divider),
                          Expanded(
                            child: _Sidebar(state: state, cubit: cubit),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Кнопки управления
              Positioned(
                left: 33,
                top: 938,
                child: ArcadeButton(
                  size: 86,
                  kind: ArcadeKind.yellow,
                  icon: const ArcadeTriangle(ArcadeDir.left),
                  repeat: true,
                  onPressed: cubit.moveLeft,
                ),
              ),
              Positioned(
                left: 193,
                top: 938,
                child: ArcadeButton(
                  size: 86,
                  kind: ArcadeKind.yellow,
                  icon: const ArcadeTriangle(ArcadeDir.right),
                  repeat: true,
                  onPressed: cubit.moveRight,
                ),
              ),
              Positioned(
                left: 113,
                top: 1019,
                child: ArcadeButton(
                  size: 86,
                  kind: ArcadeKind.yellow,
                  icon: const ArcadeTriangle(ArcadeDir.down),
                  repeat: true,
                  onPressed: () => cubit.moveDown(soft: true),
                ),
              ),
              Positioned(
                left: 347,
                top: 995,
                child: ArcadeButton(
                  size: 110,
                  kind: ArcadeKind.blue,
                  icon: const Icon(
                    Icons.sync,
                    size: 70,
                    color: Color(0xFF1B6598),
                  ),
                  onPressed: cubit.rotate,
                ),
              ),
              Positioned(
                left: 468,
                top: 937,
                child: ArcadeButton(
                  size: 88,
                  kind: ArcadeKind.blue,
                  icon: const Icon(
                    Icons.keyboard_double_arrow_down,
                    size: 58,
                    color: Color(0xFF0B5A8F),
                  ),
                  heavy: true,
                  onPressed: cubit.hardDrop,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════ ИГРОВОЕ ПОЛЕ ═════════════════════════

const int _kGlowMs = 180;

class _BoardView extends StatefulWidget {
  final GameState state;
  final GameCubit cubit;

  const _BoardView({required this.state, required this.cubit});

  @override
  State<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<_BoardView> with TickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: GameCubit.clearDuration,
  );
  late final Ticker _ticker = createTicker((_) => _onTick());
  final Stopwatch _clock = Stopwatch()..start();
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  /// Момент, когда клетка «погасла» (для послесвечения).
  final List<List<Duration?>> _glowAt = List.generate(
    GameCubit.rows,
    (_) => List<Duration?>.filled(GameCubit.cols, null),
  );

  late List<List<bool>> _prevOn;

  @override
  void initState() {
    super.initState();
    _prevOn = _onGrid(widget.state);
  }

  List<List<bool>> _onGrid(GameState s) {
    final grid = List.generate(
      GameCubit.rows,
      (r) => List.generate(GameCubit.cols, (c) => s.board[r][c] != null),
    );
    for (final p in s.currentPiece?.positions ?? const <Position>[]) {
      if (p.y >= 0 &&
          p.y < GameCubit.rows &&
          p.x >= 0 &&
          p.x < GameCubit.cols) {
        grid[p.y][p.x] = true;
      }
    }
    return grid;
  }

  @override
  void didUpdateWidget(covariant _BoardView old) {
    super.didUpdateWidget(old);

    final now = _onGrid(widget.state);
    final t = _clock.elapsed;
    var anyGlow = false;

    for (var r = 0; r < GameCubit.rows; r++) {
      for (var c = 0; c < GameCubit.cols; c++) {
        if (_prevOn[r][c] && !now[r][c]) {
          _glowAt[r][c] = t;
          anyGlow = true;
        } else if (now[r][c]) {
          _glowAt[r][c] = null;
        }
      }
    }
    _prevOn = now;

    if (anyGlow && !_ticker.isActive) _ticker.start();

    if (old.state.clearingRows.isEmpty &&
        widget.state.clearingRows.isNotEmpty) {
      _flash.forward(from: 0);
    }
  }

  void _onTick() {
    final now = _clock.elapsed;
    var active = false;
    for (final row in _glowAt) {
      for (var c = 0; c < row.length; c++) {
        final t = row[c];
        if (t == null) continue;
        if ((now - t).inMilliseconds >= _kGlowMs) {
          row[c] = null;
        } else {
          active = true;
        }
      }
    }
    _tick.value++;
    if (!active) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flash.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return _BoardGestures(
      cubit: widget.cubit,
      child: SizedBox(
        width: 372,
        height: 744,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _BoardPainter(
                board: state.board,
                piece: state.currentPiece?.positions ?? const [],
                ghost: widget.cubit.getGhostPositions(),
                clearingRows: state.clearingRows,
                flash: _flash,
                glowAt: _glowAt,
                clock: _clock,
                repaint: Listenable.merge([_flash, _tick]),
              ),
            ),
            if (state.status == GameStatus.paused)
              Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Text(
                  'PAUSE',
                  style: TextStyle(
                    fontFamily: kPixelFontFamily,
                    fontSize: 26,
                    color: RetroColors.label,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<List<Color?>> board;
  final List<Position> piece;
  final List<Position> ghost;
  final List<int> clearingRows;
  final Animation<double> flash;
  final List<List<Duration?>> glowAt;
  final Stopwatch clock;

  _BoardPainter({
    required this.board,
    required this.piece,
    required this.ghost,
    required this.clearingRows,
    required this.flash,
    required this.glowAt,
    required this.clock,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / GameCubit.cols;
    final now = clock.elapsed;

    // 6 фаз за время очистки: заполнено → пусто → … → пусто (3 мигания).
    final hideClearing =
        clearingRows.isNotEmpty && (flash.value * 6).floor().isOdd;

    final grid = List.generate(
      GameCubit.rows,
      (r) => List.generate(GameCubit.cols, (c) {
        if (board[r][c] == null) return LcdCell.empty;
        if (hideClearing && clearingRows.contains(r)) return LcdCell.empty;
        return LcdCell.filled;
      }),
    );

    for (final p in ghost) {
      if (p.y >= 0 &&
          p.y < GameCubit.rows &&
          p.x >= 0 &&
          p.x < GameCubit.cols) {
        if (grid[p.y][p.x] == LcdCell.empty) grid[p.y][p.x] = LcdCell.ghost;
      }
    }
    for (final p in piece) {
      if (p.y >= 0 &&
          p.y < GameCubit.rows &&
          p.x >= 0 &&
          p.x < GameCubit.cols) {
        grid[p.y][p.x] = LcdCell.filled;
      }
    }

    for (int r = 0; r < GameCubit.rows; r++) {
      for (int c = 0; c < GameCubit.cols; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        final style = grid[r][c];

        if (style == LcdCell.empty) {
          final t = glowAt[r][c];
          if (t != null) {
            final g = 1 - (now - t).inMilliseconds / _kGlowMs;
            if (g > 0) {
              paintLcdCell(canvas, rect, LcdCell.filled, alpha: g * 0.28);
              continue;
            }
          }
        }
        paintLcdCell(canvas, rect, style);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

/// Мини-превью фигуры (NEXT / HOLD / декоративная L).
class _PiecePainter extends CustomPainter {
  final List<Position> cells;
  final double cell;

  const _PiecePainter(this.cells, this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;

    var minX = cells.first.x, maxX = cells.first.x;
    var minY = cells.first.y, maxY = cells.first.y;
    for (final p in cells) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final w = (maxX - minX + 1) * cell;
    final h = (maxY - minY + 1) * cell;
    final origin = Offset((size.width - w) / 2, (size.height - h) / 2);

    for (final p in cells) {
      paintLcdCell(
        canvas,
        Rect.fromLTWH(
          origin.dx + (p.x - minX) * cell,
          origin.dy + (p.y - minY) * cell,
          cell,
          cell,
        ),
        LcdCell.filled,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) => true;
}

// ═════════════════════════ БОКОВАЯ ПАНЕЛЬ ═════════════════════════

class _Sidebar extends StatelessWidget {
  final GameState state;
  final GameCubit cubit;

  const _Sidebar({required this.state, required this.cubit});

  static const _decorativeL = [
    Position(0, 0),
    Position(0, 1),
    Position(0, 2),
    Position(1, 2),
  ];

  /// Четыре верхние плитки зависят от режима. В Marathon — как на референсе.
  List<Widget> _tiles(GameState s) {
    final speed = _StatTile('SPEED', '${s.level}');
    final score = _StatTile('SCORE', '${s.score}');

    switch (s.mode) {
      case GameMode.marathon:
        return [
          speed,
          const _StatTile('GOAL', ''),
          score,
          _StatTile('HI-SCORE', '${s.highScore}'),
        ];
      case GameMode.sprint:
        return [
          speed,
          _StatTile('LINES', '${math.max(0, kSprintLines - s.lines)}'),
          score,
          _StatTile('TIME', formatClock(s.elapsedMs)),
        ];
      case GameMode.ultra:
        return [
          speed,
          _StatTile(
            'TIME',
            formatClock(math.max(0, kUltraSeconds * 1000 - s.elapsedMs)),
          ),
          score,
          _StatTile('HI-SCORE', '${s.highScore}'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        ..._tiles(state),

        const SizedBox(height: 8),
        const _Label('NEXT'),
        const SizedBox(height: 3),
        _PreviewBox(
          child: CustomPaint(
            painter: _PiecePainter(state.nextPiece?.positions ?? const [], 18),
          ),
        ),
        const SizedBox(height: 10),
        const _PreviewBox(
          child: CustomPaint(painter: _PiecePainter(_decorativeL, 17)),
        ),
        const SizedBox(height: 7),
        const _Label('HOLD'),
        const SizedBox(height: 3),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.medium();
            cubit.holdPiece();
          },
          child: _PreviewBox(
            child: state.heldPiece == null
                ? const Center(
                    child: Text(
                      'TOUCH\nTO HOLD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: RetroColors.hint,
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _PiecePainter(state.heldPiece!.positions, 18),
                  ),
          ),
        ),
        const SizedBox(height: 15),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.selection();
            cubit.togglePause();
          },
          child: Container(
            width: 93,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: RetroColors.lcdBorder, width: 2),
            ),
            child: const _PauseIcon(),
          ),
        ),
      ],
    );
  }
}

/// Блок «заголовок + значение» высотой 79 с линией снизу.
class _StatTile extends StatelessWidget {
  final String title;
  final String value;

  const _StatTile(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 79,
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RetroColors.line, width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          _Label(title),
          const SizedBox(height: 4),
          Container(
            width: 93,
            height: 38,
            alignment: Alignment.center,
            color: RetroColors.box,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: RetroColors.value,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: RetroColors.label,
          ),
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final Widget child;

  const _PreviewBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 93,
      height: 93,
      color: RetroColors.box,
      child: child,
    );
  }
}

class _PauseIcon extends StatelessWidget {
  const _PauseIcon();

  @override
  Widget build(BuildContext context) {
    Widget bar() =>
        Container(width: 4, height: 20, color: RetroColors.lcdBorder);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [bar(), const SizedBox(width: 7), bar()],
    );
  }
}

// ═════════════════════════ ЖЕСТЫ И ЖИЗНЕННЫЙ ЦИКЛ ═════════════════════════

/// Управление свайпами по полю:
/// влево/вправо — сдвиг, вниз — мягкое падение, быстрый свайп вверх —
/// мгновенное падение, тап — поворот.
class _BoardGestures extends StatefulWidget {
  final GameCubit cubit;
  final Widget child;

  const _BoardGestures({required this.cubit, required this.child});

  @override
  State<_BoardGestures> createState() => _BoardGesturesState();
}

class _BoardGesturesState extends State<_BoardGestures> {
  static const double _step = 34; // дизайн-пикселей на один шаг
  static const double _flingSpeed = 900;

  double _ax = 0;
  double _ay = 0;

  void _onUpdate(DragUpdateDetails d) {
    _ax += d.delta.dx;
    _ay += d.delta.dy;

    while (_ax >= _step) {
      widget.cubit.moveRight();
      Haptics.selection();
      _ax -= _step;
    }
    while (_ax <= -_step) {
      widget.cubit.moveLeft();
      Haptics.selection();
      _ax += _step;
    }
    while (_ay >= _step) {
      widget.cubit.moveDown(soft: true);
      _ay -= _step;
    }
    if (_ay < 0) _ay = 0;
  }

  void _onEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (v.dy < -_flingSpeed && v.dy.abs() > v.dx.abs()) {
      Haptics.heavy();
      widget.cubit.hardDrop();
    }
    _ax = 0;
    _ay = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSettings.gesturesOn) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.selection();
        widget.cubit.rotate();
      },
      onPanStart: (_) {
        _ax = 0;
        _ay = 0;
      },
      onPanUpdate: _onUpdate,
      onPanEnd: _onEnd,
      child: widget.child,
    );
  }
}

/// Ставит игру на паузу и сохраняет партию, когда приложение уходит в фон.
class _LifecyclePause extends StatefulWidget {
  final Widget child;

  const _LifecyclePause({required this.child});

  @override
  State<_LifecyclePause> createState() => _LifecyclePauseState();
}

class _LifecyclePauseState extends State<_LifecyclePause>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      context.read<GameCubit>().pauseIfPlaying();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
