import 'package:cyber_brick/features/data/domain/entities/game_mode.dart';
import 'package:cyber_brick/features/data/domain/entities/tetromino.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum GameStatus { initial, playing, paused, gameOver, completed }

class GameState extends Equatable {
  final GameStatus status;
  final List<List<Color?>> board;
  final Tetromino? currentPiece;
  final Tetromino? nextPiece;
  final Tetromino? heldPiece;
  final bool canHold;
  final int score;
  final int highScore;
  final int level;
  final int lines;

  /// Строки, которые сейчас мигают перед удалением (анимация очистки).
  final List<int> clearingRows;

  final GameMode mode;

  /// Время партии в миллисекундах (обновляется раз в секунду).
  final int elapsedMs;

  /// Только что открытые достижения (для уведомления). Каждый раз — новый список.
  final List<String> unlocked;

  const GameState({
    required this.status,
    required this.board,
    required this.currentPiece,
    required this.nextPiece,
    this.heldPiece,
    this.canHold = true,
    required this.score,
    required this.highScore,
    required this.level,
    this.lines = 0,
    this.clearingRows = const [],
    this.mode = GameMode.marathon,
    this.elapsedMs = 0,
    this.unlocked = const [],
  });

  factory GameState.initial() {
    const rows = 20;
    const cols = 10;
    final emptyBoard = List.generate(
      rows,
      (_) => List<Color?>.filled(cols, null),
    );
    return GameState(
      status: GameStatus.initial,
      board: emptyBoard,
      currentPiece: null,
      nextPiece: null,
      heldPiece: null,
      canHold: true,
      score: 0,
      highScore: 250,
      level: 1,
    );
  }

  /// Флаги clear* нужны, чтобы можно было явно обнулить nullable-поле.
  GameState copyWith({
    GameStatus? status,
    List<List<Color?>>? board,
    Tetromino? currentPiece,
    Tetromino? nextPiece,
    Tetromino? heldPiece,
    bool clearCurrent = false,
    bool clearNext = false,
    bool clearHeld = false,
    bool? canHold,
    int? score,
    int? highScore,
    int? level,
    int? lines,
    List<int>? clearingRows,
    GameMode? mode,
    int? elapsedMs,
    List<String>? unlocked,
  }) {
    return GameState(
      status: status ?? this.status,
      board: board ?? this.board,
      currentPiece: clearCurrent ? null : (currentPiece ?? this.currentPiece),
      nextPiece: clearNext ? null : (nextPiece ?? this.nextPiece),
      heldPiece: clearHeld ? null : (heldPiece ?? this.heldPiece),
      canHold: canHold ?? this.canHold,
      score: score ?? this.score,
      highScore: highScore ?? this.highScore,
      level: level ?? this.level,
      lines: lines ?? this.lines,
      clearingRows: clearingRows ?? this.clearingRows,
      mode: mode ?? this.mode,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  @override
  List<Object?> get props => [
    status,
    board,
    currentPiece,
    nextPiece,
    heldPiece,
    canHold,
    score,
    highScore,
    level,
    lines,
    clearingRows,
    mode,
    elapsedMs,
    unlocked,
  ];
}
