import 'dart:math';

import 'package:flutter/material.dart';

import 'position.dart';

enum TetrominoType { i, j, l, o, s, t, z }

class Tetromino {
  final TetrominoType type;
  List<Position> positions;
  final Color color;
  final int pivotIndex;

  Tetromino({
    required this.type,
    required this.positions,
    required this.color,
    this.pivotIndex = 1,
  });

  static final Random _random = Random();

  static Tetromino generateRandom() => fromType(
    TetrominoType.values[_random.nextInt(TetrominoType.values.length)],
  );

  static Tetromino fromType(TetrominoType type) {
    switch (type) {
      case TetrominoType.i:
        return Tetromino(
          type: type,
          color: Colors.cyan,
          pivotIndex: 1,
          positions: const [
            Position(3, 0),
            Position(4, 0),
            Position(5, 0),
            Position(6, 0),
          ],
        );
      case TetrominoType.j:
        return Tetromino(
          type: type,
          color: Colors.blue,
          pivotIndex: 2,
          positions: const [
            Position(3, 0),
            Position(3, 1),
            Position(4, 1),
            Position(5, 1),
          ],
        );
      case TetrominoType.l:
        return Tetromino(
          type: type,
          color: Colors.orange,
          pivotIndex: 2,
          positions: const [
            Position(5, 0),
            Position(3, 1),
            Position(4, 1),
            Position(5, 1),
          ],
        );
      case TetrominoType.o:
        return Tetromino(
          type: type,
          color: Colors.amber,
          pivotIndex: 0,
          positions: const [
            Position(4, 0),
            Position(5, 0),
            Position(4, 1),
            Position(5, 1),
          ],
        );
      case TetrominoType.s:
        return Tetromino(
          type: type,
          color: Colors.green,
          pivotIndex: 3,
          positions: const [
            Position(4, 0),
            Position(5, 0),
            Position(3, 1),
            Position(4, 1),
          ],
        );
      case TetrominoType.t:
        return Tetromino(
          type: type,
          color: Colors.purple,
          pivotIndex: 2,
          positions: const [
            Position(4, 0),
            Position(3, 1),
            Position(4, 1),
            Position(5, 1),
          ],
        );
      case TetrominoType.z:
        return Tetromino(
          type: type,
          color: Colors.red,
          pivotIndex: 2,
          positions: const [
            Position(3, 0),
            Position(4, 0),
            Position(4, 1),
            Position(5, 1),
          ],
        );
    }
  }

  Tetromino respawn() => fromType(type);

  Tetromino clone() {
    return Tetromino(
      type: type,
      positions: positions.map((p) => Position(p.x, p.y)).toList(),
      color: color,
      pivotIndex: pivotIndex,
    );
  }

  /// Сериализация фигуры для сохранения игры
  Map<String, dynamic> toJson() => {
    'type': type.index,
    'positions': positions.map((p) => [p.x, p.y]).toList(),
  };

  /// Восстановление фигуры из JSON
  static Tetromino fromJson(Map data) {
    final piece = fromType(TetrominoType.values[data['type'] as int]);
    piece.positions = (data['positions'] as List).map((e) {
      final xy = e as List;
      return Position(xy[0] as int, xy[1] as int);
    }).toList();
    return piece;
  }
}
