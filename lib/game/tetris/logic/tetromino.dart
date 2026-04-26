import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tetromino_shapes.dart';

class Tetromino {
  final TetrominoType type;
  int currentRotation;

  Tetromino(this.type) : currentRotation = 0;

  List<List<List<int>>> get _rotations {
    switch (type) {
      case TetrominoType.I:
        return TetrominoShapes.I;
      case TetrominoType.O:
        return TetrominoShapes.O;
      case TetrominoType.T:
        return TetrominoShapes.T;
      case TetrominoType.S:
        return TetrominoShapes.S;
      case TetrominoType.Z:
        return TetrominoShapes.Z;
      case TetrominoType.J:
        return TetrominoShapes.J;
      case TetrominoType.L:
        return TetrominoShapes.L;
    }
  }

  List<List<int>> get currentShape => _rotations[currentRotation];

  Color get color => TetrominoColors.getColor(type);

  void rotateClockwise() {
    currentRotation = (currentRotation + 1) % 4;
  }

  void rotateCounterClockwise() {
    currentRotation = (currentRotation + 3) % 4;
  }

  Tetromino clone() {
    final t = Tetromino(type);
    t.currentRotation = currentRotation;
    return t;
  }

  static Tetromino random() {
    final types = TetrominoType.values;
    final index = Random().nextInt(types.length);
    return Tetromino(types[index]);
  }

  static Tetromino fromType(TetrominoType type) => Tetromino(type);
}
