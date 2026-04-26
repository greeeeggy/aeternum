import 'package:flutter/material.dart';

enum TetrominoType { I, O, T, S, Z, J, L }

class TetrominoShapes {
  // I-piece (Cyan) - 4x4
  static const List<List<List<int>>> I = [
    [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0]
    ],
    [
      [0, 0, 1, 0],
      [0, 0, 1, 0],
      [0, 0, 1, 0],
      [0, 0, 1, 0]
    ],
    [
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [0, 0, 0, 0]
    ],
    [
      [0, 1, 0, 0],
      [0, 1, 0, 0],
      [0, 1, 0, 0],
      [0, 1, 0, 0]
    ],
  ];

  // O-piece (Yellow) - 2x2
  static const List<List<List<int>>> O = [
    [
      [1, 1],
      [1, 1]
    ],
    [
      [1, 1],
      [1, 1]
    ],
    [
      [1, 1],
      [1, 1]
    ],
    [
      [1, 1],
      [1, 1]
    ],
  ];

  // T-piece (Purple) - 3x3
  static const List<List<List<int>>> T = [
    [
      [0, 1, 0],
      [1, 1, 1],
      [0, 0, 0]
    ],
    [
      [0, 1, 0],
      [0, 1, 1],
      [0, 1, 0]
    ],
    [
      [0, 0, 0],
      [1, 1, 1],
      [0, 1, 0]
    ],
    [
      [0, 1, 0],
      [1, 1, 0],
      [0, 1, 0]
    ],
  ];

  // S-piece (Green) - 3x3
  static const List<List<List<int>>> S = [
    [
      [0, 1, 1],
      [1, 1, 0],
      [0, 0, 0]
    ],
    [
      [0, 1, 0],
      [0, 1, 1],
      [0, 0, 1]
    ],
    [
      [0, 0, 0],
      [0, 1, 1],
      [1, 1, 0]
    ],
    [
      [1, 0, 0],
      [1, 1, 0],
      [0, 1, 0]
    ],
  ];

  // Z-piece (Red) - 3x3
  static const List<List<List<int>>> Z = [
    [
      [1, 1, 0],
      [0, 1, 1],
      [0, 0, 0]
    ],
    [
      [0, 0, 1],
      [0, 1, 1],
      [0, 1, 0]
    ],
    [
      [0, 0, 0],
      [1, 1, 0],
      [0, 1, 1]
    ],
    [
      [0, 1, 0],
      [1, 1, 0],
      [1, 0, 0]
    ],
  ];

  // J-piece (Blue) - 3x3
  static const List<List<List<int>>> J = [
    [
      [1, 0, 0],
      [1, 1, 1],
      [0, 0, 0]
    ],
    [
      [0, 1, 1],
      [0, 1, 0],
      [0, 1, 0]
    ],
    [
      [0, 0, 0],
      [1, 1, 1],
      [0, 0, 1]
    ],
    [
      [0, 1, 0],
      [0, 1, 0],
      [1, 1, 0]
    ],
  ];

  // L-piece (Orange) - 3x3
  static const List<List<List<int>>> L = [
    [
      [0, 0, 1],
      [1, 1, 1],
      [0, 0, 0]
    ],
    [
      [0, 1, 0],
      [0, 1, 0],
      [0, 1, 1]
    ],
    [
      [0, 0, 0],
      [1, 1, 1],
      [1, 0, 0]
    ],
    [
      [1, 1, 0],
      [0, 1, 0],
      [0, 1, 0]
    ],
  ];
}

class TetrominoColors {
  static const Map<TetrominoType, Color> colors = {
    TetrominoType.I: Color(0xFF00FFFF), // Cyan
    TetrominoType.O: Color(0xFFFFFF00), // Yellow
    TetrominoType.T: Color(0xFF9B30FF), // Purple
    TetrominoType.S: Color(0xFF00FF00), // Green
    TetrominoType.Z: Color(0xFFFF0000), // Red
    TetrominoType.J: Color(0xFF0000FF), // Blue
    TetrominoType.L: Color(0xFFFF7F00), // Orange
  };

  static Color getColor(TetrominoType type) => colors[type]!;

  static Color getGhostColor(TetrominoType type) =>
      colors[type]!.withOpacity(0.3);
}
