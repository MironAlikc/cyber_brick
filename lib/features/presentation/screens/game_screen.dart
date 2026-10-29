import 'dart:math' as math;

import 'package:cyber_brick/core/app_settings.dart';
import 'package:cyber_brick/core/audio_service.dart';
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

const double _designW = 589;
const double _designH = 1280;

String formatClock(int ms) =>
    '${ms ~/ 60000}:${((ms % 60000) ~/ 1000).toString().padLeft(2, '0')}';

String formatMs(int ms) {
  final secs = (ms % 60000) / 1000;
  return '${ms ~/ 60000}:${secs.toStringAsFixed(1).padLeft(4, '0')}';
}

class GameScreen extends StatelessWidget {
  final bool resume;
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
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == GameStatus.gameOver ||
              state.status == GameStatus.completed) {
            Haptics.vibrate();
          }
        },
        builder: (context, state) {
          final cubit = context.read<GameCubit>();

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (state.status == GameStatus.playing) {
                cubit.pause();
              } else if (state.status == GameStatus.paused) {
                cubit.resume();
              }
            },
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 80,
                  child: Text(
                    'CYBER BRICK',
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
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                _BoardView(state: state, cubit: cubit),
                                Container(width: 2, color: RetroColors.divider),
                                Expanded(
                                  child: _Sidebar(state: state, cubit: cubit),
                                ),
                              ],
                            ),
                            if (state.status == GameStatus.paused)
                              const PauseMenu(),
                            if (state.status == GameStatus.gameOver ||
                                state.status == GameStatus.completed)
                              GameOverMenu(state: state),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════ МЕНЮ ПАУЗЫ И GAME OVER ═════════════════════════

class PauseMenu extends StatelessWidget {
  const PauseMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();

    return Container(
      color: RetroColors.lcd.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: RetroColors.lcd,
          border: Border.all(color: RetroColors.lcdBorder, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSE',
              style: TextStyle(
                fontFamily: kPixelFontFamily,
                fontSize: 24,
                color: RetroColors.label,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            RetroMenuButton(
              label: 'RESUME',
              onTap: () {
                Haptics.selection();
                cubit.resume();
              },
            ),
            const SizedBox(height: 10),
            RetroMenuButton(
              label: 'RESTART',
              onTap: () {
                Haptics.selection();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogCtx) => RetroDialog(
                    title: 'RESTART GAME?\nPROGRESS WILL BE LOST',
                    onConfirm: () {
                      Navigator.of(dialogCtx).pop();
                      cubit.restart();
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            RetroMenuButton(
              label: 'QUIT TO MENU',
              onTap: () {
                Haptics.selection();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogCtx) => RetroDialog(
                    title: 'QUIT TO MENU?\nPROGRESS WILL BE LOST',
                    onConfirm: () {
                      Navigator.of(dialogCtx).pop();
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverMenu extends StatelessWidget {
  final GameState state;

  const GameOverMenu({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GameCubit>();
    final isOver = state.status == GameStatus.gameOver;
    final isSprint = state.mode == GameMode.sprint;

    return Container(
      color: RetroColors.lcd.withValues(alpha: 0.92),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: RetroColors.lcd,
          border: Border.all(color: RetroColors.lcdBorder, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOver ? 'GAME OVER' : (isSprint ? 'COMPLETE' : 'TIME UP'),
              style: const TextStyle(
                fontFamily: kPixelFontFamily,
                fontSize: 22,
                color: RetroColors.label,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (!isOver && isSprint)
                  ? 'TIME: ${formatMs(state.elapsedMs)}'
                  : 'SCORE: ${state.score}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: RetroColors.value,
              ),
            ),
            const SizedBox(height: 24),
            RetroMenuButton(
              label: 'PLAY AGAIN',
              onTap: () {
                Haptics.medium();
                cubit.restart();
              },
            ),
            const SizedBox(height: 10),
            RetroMenuButton(
              label: 'MAIN MENU',
              onTap: () {
                Haptics.selection();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RetroMenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const RetroMenuButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AudioService.instance.play(Sfx.click);
        onTap();
      },
      child: Container(
        width: 240,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RetroColors.darkButton,
          border: Border.all(color: RetroColors.lcdBorder, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: kPixelFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: RetroColors.darkButtonText,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class RetroDialog extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;

  const RetroDialog({super.key, required this.title, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RetroColors.lcd,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: RetroColors.lcdBorder, width: 2),
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: kPixelFontFamily,
                fontSize: 13,
                height: 1.4,
                color: RetroColors.label,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: RetroMenuButton(
                    label: 'YES',
                    onTap: () {
                      Haptics.heavy();
                      onConfirm();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RetroMenuButton(
                    label: 'NO',
                    onTap: () {
                      Haptics.selection();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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

    // Ширина левой панели под игровое поле закреплена на уровне ~372 пикселей.
    // Обертываем в AspectRatio, чтобы ячейки оставались идеально квадратными (10 колонок на 20 строк).
    return SizedBox(
      width: 372,
      child: _BoardGestures(
        cubit: widget.cubit,
        child: Center(
          child: AspectRatio(
            aspectRatio: GameCubit.cols / GameCubit.rows,
            child: CustomPaint(
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
          ),
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
            if (state.status != GameStatus.playing) return;
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
        BlocSelector<GameCubit, GameState, GameStatus>(
          selector: (s) => s.status,
          builder: (context, status) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.selection();
                if (status == GameStatus.playing) {
                  cubit.pause();
                } else if (status == GameStatus.paused) {
                  cubit.resume();
                } else if (status == GameStatus.gameOver ||
                    status == GameStatus.completed) {
                  cubit.restart();
                }
              },
              child: Container(
                width: 93,
                height: 37,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: RetroColors.lcdBorder, width: 2),
                ),
                child: PauseButtonIcon(status: status),
              ),
            );
          },
        ),
      ],
    );
  }
}

class PauseButtonIcon extends StatelessWidget {
  final GameStatus status;

  const PauseButtonIcon({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == GameStatus.paused) {
      return const Icon(
        Icons.play_arrow,
        size: 24,
        color: RetroColors.lcdBorder,
      );
    } else if (status == GameStatus.gameOver ||
        status == GameStatus.completed) {
      return const Icon(Icons.refresh, size: 22, color: RetroColors.lcdBorder);
    }
    // По умолчанию (playing) — значок паузы II
    Widget bar() =>
        Container(width: 4, height: 20, color: RetroColors.lcdBorder);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [bar(), const SizedBox(width: 7), bar()],
    );
  }
}

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

// ═════════════════════════ ЖЕСТЫ И ЖИЗНЕННЫЙ ЦИКЛ ═════════════════════════

class _BoardGestures extends StatefulWidget {
  final GameCubit cubit;
  final Widget child;

  const _BoardGestures({required this.cubit, required this.child});

  @override
  State<_BoardGestures> createState() => _BoardGesturesState();
}

class _BoardGesturesState extends State<_BoardGestures> {
  static const double _step = 34;
  static const double _flingSpeed = 900;

  double _ax = 0;
  double _ay = 0;

  void _onUpdate(DragUpdateDetails d) {
    if (widget.cubit.state.status != GameStatus.playing) return;
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
    if (widget.cubit.state.status != GameStatus.playing) return;
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
        if (widget.cubit.state.status != GameStatus.playing) return;
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
