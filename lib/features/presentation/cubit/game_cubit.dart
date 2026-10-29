import 'dart:async';
import 'dart:math';

import 'package:cyber_brick/core/audio_service.dart';
import 'package:cyber_brick/features/data/domain/entities/daily_task.dart';
import 'package:cyber_brick/features/data/domain/entities/game_mode.dart';
import 'package:cyber_brick/features/data/domain/entities/position.dart';
import 'package:cyber_brick/features/data/domain/entities/tetromino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/achievements_local_data_source.dart';
import '../../data/datasources/daily_tasks_local_data_source.dart';
import '../../data/datasources/game_local_data_source.dart';
import 'game_state.dart';

class GameCubit extends Cubit<GameState> {
  final GameLocalDataSource _localDataSource;
  final DailyTasksLocalDataSource? _tasks;
  final AchievementsLocalDataSource? _achievements;
  int _reportedScore = 0;

  Timer? _gameTimer;
  Timer? _clockTimer;

  // Время партии считается только пока игра идёт (не на паузе).
  final Stopwatch _playClock = Stopwatch();
  int _baseElapsedMs = 0;
  int get _elapsedMs => _baseElapsedMs + _playClock.elapsedMilliseconds;

  // Задержка перед фиксацией фигуры, лежащей на опоре.
  Timer? _lockTimer;
  int _lockResets = 0;
  static const Duration _lockDelay = Duration(milliseconds: 450);
  static const int _maxLockResets = 12;

  // Анимация очистки линий.
  static const Duration clearDuration = Duration(milliseconds: 360);
  Timer? _clearTimer;
  void Function()? _pendingClear;

  static const int rows = 20;
  static const int cols = 10;
  static const int linesPerLevel = 10;
  static const List<int> _lineScores = [0, 100, 300, 500, 800];

  GameCubit(this._localDataSource, {this._tasks, this._achievements})
    : super(GameState.initial());

  // ───────────────────────── Рекорды ─────────────────────────

  Future<int> _loadBest(GameMode mode) async {
    switch (mode) {
      case GameMode.marathon:
        return max(await _localDataSource.getHighScore(), 250);
      case GameMode.ultra:
        return _localDataSource.getBest(kBestUltraKey);
      case GameMode.sprint:
        return 0;
    }
  }

  Future<void> _saveHigh(int value) async {
    switch (state.mode) {
      case GameMode.marathon:
        await _localDataSource.saveHighScore(value);
        break;
      case GameMode.ultra:
        await _localDataSource.saveBest(kBestUltraKey, value);
        break;
      case GameMode.sprint:
        break;
    }
  }

  Future<void> _saveSprintBest(int ms) async {
    final best = await _localDataSource.getBest(kBestSprintKey);
    if (best == 0 || ms < best) {
      await _localDataSource.saveBest(kBestSprintKey, ms);
    }
  }

  // ───────────────────────── Достижения ─────────────────────────

  Future<void> _report({
    int lines = 0,
    bool tetris = false,
    int games = 0,
    int? score,
    int? level,
    bool sprintDone = false,
    GameMode? mode,
  }) async {
    final ach = _achievements;
    if (ach == null) return;

    final unlocked = await ach.report(
      lines: lines,
      tetris: tetris,
      games: games,
      score: score,
      level: level,
      mode: mode ?? state.mode,
      sprintDone: sprintDone,
    );
    if (unlocked.isEmpty || isClosed) return;

    emit(
      state.copyWith(
        unlocked: [for (final a in unlocked) '${a.title} +${a.reward}'],
      ),
    );
  }

  // ───────────────────────── Игровой цикл ─────────────────────────

  /// Продолжает сохранённую партию (в паузе) или начинает новую.
  Future<void> startOrResume({
    bool resume = true,
    GameMode mode = GameMode.marathon,
  }) async {
    if (resume) {
      final saved = await _localDataSource.loadGame();
      if (isClosed) return;
      if (saved != null && await _restore(saved)) return;
    }
    await startGame(mode);
  }

  Future<void> restart() => startGame(state.mode);

  Future<void> startGame([GameMode? mode]) async {
    final m = mode ?? state.mode;

    _cancelAllTimers();
    _pendingClear = null;
    _resetLock();
    _reportedScore = 0;
    _localDataSource.clearGame();

    final best = await _loadBest(m);
    if (isClosed) return;

    _baseElapsedMs = 0;
    _playClock
      ..reset()
      ..start();

    _tasks?.addProgress(TaskId.games, 1);
    _report(games: 1, mode: m);

    emit(
      GameState(
        status: GameStatus.playing,
        board: List.generate(rows, (_) => List<Color?>.filled(cols, null)),
        currentPiece: Tetromino.generateRandom(),
        nextPiece: Tetromino.generateRandom(),
        heldPiece: null,
        canHold: true,
        score: 0,
        highScore: best,
        level: 1,
        lines: 0,
        mode: m,
      ),
    );

    _startTimer();
    _startClock();
    AudioService.instance.syncMusic();
  }

  void _cancelAllTimers() {
    _gameTimer?.cancel();
    _clockTimer?.cancel();
    _clearTimer?.cancel();
    _lockTimer?.cancel();
    _clearTimer = null;
    _lockTimer = null;
  }

  Duration get _tickDuration =>
      Duration(milliseconds: max(100, 500 - (state.level - 1) * 40));

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(_tickDuration, (_) {
      if (state.status == GameStatus.playing) moveDown();
    });
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _onClock(),
    );
  }

  void _onClock() {
    if (state.status != GameStatus.playing) return;

    final ms = _elapsedMs;
    if (state.mode == GameMode.ultra && ms >= kUltraSeconds * 1000) {
      _finish();
      return;
    }
    if (ms ~/ 1000 != state.elapsedMs ~/ 1000) {
      emit(state.copyWith(elapsedMs: ms));
    }
  }

  void togglePause() {
    if (state.clearingRows.isNotEmpty) _flushClear();

    if (state.status == GameStatus.playing) {
      _gameTimer?.cancel();
      _clockTimer?.cancel();
      _playClock.stop();
      _cancelLock();
      emit(state.copyWith(status: GameStatus.paused, elapsedMs: _elapsedMs));
      saveGame();
    } else if (state.status == GameStatus.paused) {
      emit(state.copyWith(status: GameStatus.playing));
      _playClock.start();
      _startTimer();
      _startClock();
    }
  }

  /// Вызывается при сворачивании приложения.
  void pauseIfPlaying() {
    if (state.status == GameStatus.playing) togglePause();
  }

  /// Завершение партии по условию режима (Sprint — 40 линий, Ultra — время).
  void _finish() {
    if (state.clearingRows.isNotEmpty) _flushClear();
    if (state.status != GameStatus.playing) return;

    _gameTimer?.cancel();
    _clockTimer?.cancel();
    _playClock.stop();
    _resetLock();

    final elapsed = _elapsedMs;
    final mode = state.mode;

    if (mode == GameMode.sprint) _saveSprintBest(elapsed);
    _localDataSource.clearGame();
    AudioService.instance.play(Sfx.claim);

    emit(
      state.copyWith(
        status: GameStatus.completed,
        clearCurrent: true,
        clearNext: true,
        canHold: false,
        elapsedMs: elapsed,
      ),
    );

    _report(sprintDone: mode == GameMode.sprint, mode: mode);
  }

  // ───────────────────────── Сохранение ─────────────────────────

  Future<void> saveGame() async {
    if (state.status != GameStatus.playing &&
        state.status != GameStatus.paused) {
      return;
    }
    if (state.currentPiece == null) return;

    await _localDataSource.saveGame({
      'board': state.board
          .map((row) => row.map((c) => c?.toARGB32()).toList())
          .toList(),
      'current': state.currentPiece?.toJson(),
      'next': state.nextPiece?.toJson(),
      'held': state.heldPiece?.toJson(),
      'canHold': state.canHold,
      'score': state.score,
      'level': state.level,
      'lines': state.lines,
      'mode': state.mode.index,
      'elapsedMs': _elapsedMs,
    });
  }

  Tetromino? _pieceFrom(dynamic data) =>
      data == null ? null : Tetromino.fromJson(data as Map);

  /// Возвращает true, если партия восстановлена (в состоянии паузы).
  Future<bool> _restore(Map<String, dynamic> saved) async {
    try {
      final board = (saved['board'] as List).map((row) {
        return (row as List)
            .map<Color?>((v) => v == null ? null : Color(v as int))
            .toList();
      }).toList();

      if (board.length != rows || board.any((r) => r.length != cols)) {
        return false;
      }

      final current = _pieceFrom(saved['current']);
      if (current == null) return false;

      final score = saved['score'] as int;
      final modeIndex = (saved['mode'] as int?) ?? 0;
      final mode =
          GameMode.values[modeIndex.clamp(0, GameMode.values.length - 1)];
      final elapsed = (saved['elapsedMs'] as int?) ?? 0;
      final best = await _loadBest(mode);
      if (isClosed) return false;

      _baseElapsedMs = elapsed;
      _playClock.reset();

      emit(
        GameState(
          status: GameStatus.paused,
          board: board,
          currentPiece: current,
          nextPiece: _pieceFrom(saved['next']),
          heldPiece: _pieceFrom(saved['held']),
          canHold: saved['canHold'] as bool,
          score: score,
          highScore: max(best, score),
          level: saved['level'] as int,
          lines: saved['lines'] as int,
          mode: mode,
          elapsedMs: elapsed,
        ),
      );
      return true;
    } catch (_) {
      _localDataSource.clearGame();
      return false;
    }
  }

  // ───────────────────────── Вспомогательное ─────────────────────────

  bool get _isPlaying =>
      state.currentPiece != null && state.status == GameStatus.playing;

  bool _isValid(List<Position> positions) {
    for (final p in positions) {
      if (p.x < 0 || p.x >= cols || p.y >= rows) return false;
      if (p.y >= 0 && state.board[p.y][p.x] != null) return false;
    }
    return true;
  }

  List<Position> _shift(List<Position> positions, int dx, int dy) =>
      positions.map((p) => Position(p.x + dx, p.y + dy)).toList();

  bool get _grounded => !_isValid(_shift(state.currentPiece!.positions, 0, 1));

  // ───────────────────────── Задержка фиксации ─────────────────────────

  void _cancelLock() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  void _resetLock() {
    _cancelLock();
    _lockResets = 0;
  }

  void _startLockDelay() {
    if (_lockTimer != null) return;
    _lockTimer = Timer(_lockDelay, () {
      _lockTimer = null;
      if (_isPlaying && _grounded) _lockPiece();
    });
  }

  /// После успешного сдвига/поворота: если фигура снова может падать —
  /// отменяем фиксацию, если всё ещё на опоре — продлеваем (с лимитом).
  void _onPieceMoved() {
    if (_lockTimer == null) return;
    if (!_grounded) {
      _cancelLock();
      return;
    }
    if (_lockResets < _maxLockResets) {
      _lockResets++;
      _cancelLock();
      _startLockDelay();
    }
  }

  // ───────────────────────── Призрак ─────────────────────────

  List<Position> getGhostPositions() {
    final piece = state.currentPiece;
    if (piece == null) return [];

    var ghost = piece.positions;
    while (true) {
      final next = _shift(ghost, 0, 1);
      if (!_isValid(next)) break;
      ghost = next;
    }
    return ghost;
  }

  // ───────────────────────── Управление ─────────────────────────

  void hardDrop() {
    if (!_isPlaying) return;

    final ghost = getGhostPositions();
    final dropped = ghost.first.y - state.currentPiece!.positions.first.y;

    final piece = state.currentPiece!.clone()..positions = ghost;
    emit(state.copyWith(currentPiece: piece, score: state.score + dropped * 2));
    _lockPiece(hard: true);
  }

  void holdPiece() {
    if (!_isPlaying || !state.canHold) return;

    final current = state.currentPiece!;
    final held = state.heldPiece;

    final Tetromino newCurrent;
    Tetromino? newNext = state.nextPiece;

    if (held == null) {
      newCurrent = state.nextPiece ?? Tetromino.generateRandom();
      newNext = Tetromino.generateRandom();
    } else {
      newCurrent = held.respawn();
    }

    AudioService.instance.play(Sfx.hold);
    _resetLock();
    emit(
      state.copyWith(
        heldPiece: current.respawn(),
        currentPiece: newCurrent,
        nextPiece: newNext,
        canHold: false,
      ),
    );
  }

  /// [soft] = true, когда игрок сам тянет фигуру вниз (+1 очко).
  /// Если фигура уже на опоре, soft-движение фиксирует её сразу,
  /// а обычный тик гравитации запускает задержку фиксации.
  void moveDown({bool soft = false}) {
    if (!_isPlaying) return;

    final piece = state.currentPiece!;
    final moved = _shift(piece.positions, 0, 1);

    if (_isValid(moved)) {
      _cancelLock();
      emit(
        state.copyWith(
          currentPiece: piece.clone()..positions = moved,
          score: soft ? state.score + 1 : null,
        ),
      );
    } else if (soft) {
      _lockPiece();
    } else {
      _startLockDelay();
    }
  }

  void moveLeft() => _moveHorizontally(-1);

  void moveRight() => _moveHorizontally(1);

  void _moveHorizontally(int dx) {
    if (!_isPlaying) return;

    final piece = state.currentPiece!;
    final moved = _shift(piece.positions, dx, 0);
    if (!_isValid(moved)) return;

    emit(state.copyWith(currentPiece: piece.clone()..positions = moved));
    AudioService.instance.play(Sfx.move);
    _onPieceMoved();
  }

  void rotate() {
    if (!_isPlaying) return;

    final piece = state.currentPiece!;
    if (piece.type == TetrominoType.o) return;

    final pivot = piece.positions[piece.pivotIndex];
    final rotated = piece.positions.map((p) {
      final dx = p.x - pivot.x;
      final dy = p.y - pivot.y;
      return Position(pivot.x - dy, pivot.y + dx);
    }).toList();

    for (final kick in const [0, -1, 1, -2, 2]) {
      final candidate = _shift(rotated, kick, 0);
      if (_isValid(candidate)) {
        emit(
          state.copyWith(currentPiece: piece.clone()..positions = candidate),
        );
        AudioService.instance.play(Sfx.rotate);
        _onPieceMoved();
        return;
      }
    }
  }

  // ───────────────────────── Фиксация фигуры ─────────────────────────

  void _lockPiece({bool hard = false}) {
    _resetLock();

    final piece = state.currentPiece!;
    final newBoard = state.board.map((row) => List<Color?>.from(row)).toList();

    for (final pos in piece.positions) {
      if (pos.y >= 0 && pos.y < rows && pos.x >= 0 && pos.x < cols) {
        newBoard[pos.y][pos.x] = piece.color;
      }
    }

    final fullRows = <int>[
      for (int r = 0; r < rows; r++)
        if (newBoard[r].every((cell) => cell != null)) r,
    ];

    if (fullRows.isEmpty) {
      AudioService.instance.play(hard ? Sfx.drop : Sfx.lock);
      _completeLock(newBoard, const []);
      return;
    }

    // Показываем мигание заполненных линий, потом удаляем их.
    AudioService.instance.play(fullRows.length >= 4 ? Sfx.tetris : Sfx.line);
    emit(
      state.copyWith(
        board: newBoard,
        clearCurrent: true,
        clearingRows: fullRows,
        canHold: false,
      ),
    );
    _pendingClear = () => _completeLock(newBoard, fullRows);
    _clearTimer = Timer(clearDuration, _flushClear);
  }

  /// Немедленно завершает анимацию очистки (по таймеру, паузе или выходу).
  void _flushClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    final pending = _pendingClear;
    _pendingClear = null;
    pending?.call();
  }

  void _completeLock(List<List<Color?>> lockedBoard, List<int> fullRows) {
    final board = lockedBoard.map((row) => List<Color?>.from(row)).toList();

    for (final r in fullRows.reversed) {
      board.removeAt(r);
    }
    for (int i = 0; i < fullRows.length; i++) {
      board.insert(0, List<Color?>.filled(cols, null));
    }

    final clearedLines = fullRows.length;
    final newLines = state.lines + clearedLines;
    final newLevel = newLines ~/ linesPerLevel + 1;
    final newScore =
        state.score + _lineScores[clearedLines.clamp(0, 4)] * state.level;
    final newHighScore = max(newScore, state.highScore);

    if (newHighScore > state.highScore) _saveHigh(newHighScore);

    if (clearedLines > 0) _tasks?.addProgress(TaskId.lines, clearedLines);
    if (newScore > _reportedScore) {
      _reportedScore = newScore;
      _tasks?.reportScore(newScore);
    }
    _report(
      lines: clearedLines,
      tetris: clearedLines >= 4,
      score: newScore,
      level: newLevel,
    );

    final nextCurrent = state.nextPiece ?? Tetromino.generateRandom();
    final nextNext = Tetromino.generateRandom();

    final isGameOver = nextCurrent.positions.any(
      (p) => p.y >= 0 && board[p.y][p.x] != null,
    );

    if (isGameOver) {
      _gameTimer?.cancel();
      _clockTimer?.cancel();
      _playClock.stop();
      AudioService.instance.play(Sfx.gameOver);
      AudioService.instance.pauseMusic();
      _localDataSource.clearGame();
      emit(
        state.copyWith(
          status: GameStatus.gameOver,
          board: board,
          clearCurrent: true,
          clearNext: true,
          score: newScore,
          highScore: newHighScore,
          level: newLevel,
          lines: newLines,
          canHold: false,
          clearingRows: const [],
          elapsedMs: _elapsedMs,
        ),
      );
      return;
    }

    final levelChanged = newLevel != state.level;

    emit(
      state.copyWith(
        board: board,
        currentPiece: nextCurrent,
        nextPiece: nextNext,
        score: newScore,
        highScore: newHighScore,
        level: newLevel,
        lines: newLines,
        canHold: true,
        clearingRows: const [],
      ),
    );

    if (state.mode == GameMode.sprint && newLines >= kSprintLines) {
      _finish();
      return;
    }

    if (levelChanged) _startTimer();
    saveGame();
  }

  @override
  Future<void> close() async {
    _gameTimer?.cancel();
    _clockTimer?.cancel();
    _lockTimer?.cancel();
    _flushClear();
    await saveGame();
    return super.close();
  }
}
