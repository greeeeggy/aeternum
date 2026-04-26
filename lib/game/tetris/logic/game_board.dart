import '../models/tetromino_shapes.dart';
import 'tetromino.dart';

class GameBoard {
  static const int width = 10;
  static const int height = 20;

  late List<List<TetrominoType?>> _grid;

  GameBoard() {
    _initGrid();
  }

  void _initGrid() {
    _grid = List<List<TetrominoType?>>.generate(
      height,
      (_) => List<TetrominoType?>.filled(width, null),
    );
  }

  List<List<TetrominoType?>> get grid => _grid;

  bool isValidPosition(int x, int y) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }

  bool canPlacePiece(Tetromino piece, int x, int y) {
    final shape = piece.currentShape;
    final rows = shape.length;
    final cols = shape[0].length;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (shape[row][col] != 0) {
          final gridX = x + col;
          final gridY = y + row;

          if (gridX < 0 || gridX >= width) return false;
          if (gridY < 0 || gridY >= height) return false;
          if (_grid[gridY][gridX] != null) return false;
        }
      }
    }
    return true;
  }

  void lockPiece(Tetromino piece, int x, int y) {
    final shape = piece.currentShape;
    final rows = shape.length;
    final cols = shape[0].length;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (shape[row][col] != 0) {
          final gridX = x + col;
          final gridY = y + row;
          if (isValidPosition(gridX, gridY)) {
            _grid[gridY][gridX] = piece.type;
          }
        }
      }
    }
  }

  List<int> getFullLines() {
    final fullLines = <int>[];
    for (int y = 0; y < height; y++) {
      bool full = true;
      for (int x = 0; x < width; x++) {
        if (_grid[y][x] == null) {
          full = false;
          break;
        }
      }
      if (full) fullLines.add(y);
    }
    return fullLines;
  }

  List<int> clearLines() {
    final linesToClear = getFullLines();

    if (linesToClear.isEmpty) return linesToClear;

    final toRemove = linesToClear.toSet();

    // Keep only rows that are NOT full
    final surviving = <List<TetrominoType?>>[];
    for (int y = 0; y < height; y++) {
      if (!toRemove.contains(y)) surviving.add(_grid[y]);
    }

    // Prepend empty rows so total stays at height
    while (surviving.length < height) {
      surviving.insert(0, List<TetrominoType?>.filled(width, null));
    }

    _grid = surviving;
    return linesToClear;
  }

  void reset() {
    _initGrid();
  }

  int calculateGhostY(Tetromino piece, int x, int y) {
    int ghostY = y;
    while (canPlacePiece(piece, x, ghostY + 1)) {
      ghostY++;
    }
    return ghostY;
  }
}
