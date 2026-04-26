import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/tetromino_shapes.dart';
import 'game_board.dart';
import 'tetromino.dart';
import 'scoring_system.dart';
import '../services/high_score_service.dart';

class TetrisGameLogic extends ChangeNotifier {
  final GameBoard _board = GameBoard();
  final HighScoreService _highScoreService = HighScoreService();

  GameState _currentState = GameState.start;
  Tetromino? _currentPiece;
  Tetromino? _nextPiece;
  Tetromino? _heldPiece;

  int _pieceX = 0;
  int _pieceY = 0;
  int _score = 0;
  int _highScore = 0;
  int _level = 1;
  int _linesCleared = 0;
  bool _holdUsedThisTurn = false;

  // Getters
  GameState get currentState => _currentState;
  GameBoard get board => _board;
  Tetromino? get currentPiece => _currentPiece;
  Tetromino? get nextPiece => _nextPiece;
  Tetromino? get heldPiece => _heldPiece;
  int get pieceX => _pieceX;
  int get pieceY => _pieceY;
  int get score => _score;
  int get highScore => _highScore;
  int get level => _level;
  int get linesCleared => _linesCleared;

  TetrisGameLogic() {
    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    _highScore = await _highScoreService.getHighScore();
    notifyListeners();
  }

  void startGame() {
    _board.reset();
    _score = 0;
    _level = 1;
    _linesCleared = 0;
    _heldPiece = null;
    _holdUsedThisTurn = false;
    _nextPiece = Tetromino.random();
    _spawnNextPiece();
    _currentState = GameState.playing;
    notifyListeners();
  }

  void pauseGame() {
    if (_currentState == GameState.playing) {
      _currentState = GameState.paused;
      notifyListeners();
    }
  }

  void resumeGame() {
    if (_currentState == GameState.paused) {
      _currentState = GameState.playing;
      notifyListeners();
    }
  }

  void restartGame() {
    startGame();
  }

  void resetToStart() {
    _currentState = GameState.start;
    _board.reset();
    _score = 0;
    _level = 1;
    _linesCleared = 0;
    _heldPiece = null;
    _currentPiece = null;
    _nextPiece = null;
    notifyListeners();
  }

  void gameOver() {
    _currentState = GameState.gameOver;
    _saveHighScore();
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    if (_score > _highScore) {
      _highScore = _score;
      await _highScoreService.saveHighScore(_highScore);
    }
  }

  // ──────────────────────────────────────────
  // Piece movement
  // ──────────────────────────────────────────

  void movePieceLeft() {
    if (_currentState != GameState.playing || _currentPiece == null) return;
    if (_board.canPlacePiece(_currentPiece!, _pieceX - 1, _pieceY)) {
      _pieceX--;
      notifyListeners();
    }
  }

  void movePieceRight() {
    if (_currentState != GameState.playing || _currentPiece == null) return;
    if (_board.canPlacePiece(_currentPiece!, _pieceX + 1, _pieceY)) {
      _pieceX++;
      notifyListeners();
    }
  }

  void movePieceDown() {
    if (_currentState != GameState.playing || _currentPiece == null) return;
    if (_board.canPlacePiece(_currentPiece!, _pieceX, _pieceY + 1)) {
      _pieceY++;
      notifyListeners();
    } else {
      _lockPiece();
    }
  }

  void hardDrop() {
    if (_currentState != GameState.playing || _currentPiece == null) return;
    final ghostY = _board.calculateGhostY(_currentPiece!, _pieceX, _pieceY);
    final distance = ghostY - _pieceY;
    _pieceY = ghostY;
    _score += distance * 2;
    _lockPiece();
  }

  void rotatePieceClockwise() {
    if (_currentState != GameState.playing || _currentPiece == null) return;

    final originalRotation = _currentPiece!.currentRotation;
    _currentPiece!.rotateClockwise();

    if (_board.canPlacePiece(_currentPiece!, _pieceX, _pieceY)) {
      notifyListeners();
      return;
    }

    // Wall kicks
    final kicks = _getWallKicks(originalRotation, _currentPiece!.type);
    for (final kick in kicks) {
      final testX = _pieceX + kick.dx.toInt();
      final testY = _pieceY + kick.dy.toInt();
      if (_board.canPlacePiece(_currentPiece!, testX, testY)) {
        _pieceX = testX;
        _pieceY = testY;
        notifyListeners();
        return;
      }
    }

    // Revert
    _currentPiece!.currentRotation = originalRotation;
  }

  void rotatePieceCounterClockwise() {
    if (_currentState != GameState.playing || _currentPiece == null) return;

    final originalRotation = _currentPiece!.currentRotation;
    _currentPiece!.rotateCounterClockwise();

    if (_board.canPlacePiece(_currentPiece!, _pieceX, _pieceY)) {
      notifyListeners();
      return;
    }

    final kicks = _getWallKicks(originalRotation, _currentPiece!.type);
    for (final kick in kicks) {
      final testX = _pieceX + kick.dx.toInt();
      final testY = _pieceY + kick.dy.toInt();
      if (_board.canPlacePiece(_currentPiece!, testX, testY)) {
        _pieceX = testX;
        _pieceY = testY;
        notifyListeners();
        return;
      }
    }

    _currentPiece!.currentRotation = originalRotation;
  }

  void holdPiece() {
    if (_currentState != GameState.playing) return;
    if (_currentPiece == null) return;
    if (_holdUsedThisTurn) return;

    _holdUsedThisTurn = true;

    if (_heldPiece == null) {
      _heldPiece = Tetromino(_currentPiece!.type);
      _spawnNextPiece();
    } else {
      final swapped = Tetromino(_heldPiece!.type);
      _heldPiece = Tetromino(_currentPiece!.type);
      _currentPiece = swapped;
      _pieceX = (GameBoard.width - _currentPiece!.currentShape[0].length) ~/ 2;
      _pieceY = 0;

      if (!_board.canPlacePiece(_currentPiece!, _pieceX, _pieceY)) {
        gameOver();
        return;
      }
    }

    notifyListeners();
  }

  // ──────────────────────────────────────────
  // Game tick (called by animation controller)
  // ──────────────────────────────────────────

  void tick() {
    if (_currentState != GameState.playing || _currentPiece == null) return;

    if (_board.canPlacePiece(_currentPiece!, _pieceX, _pieceY + 1)) {
      _pieceY++;
      notifyListeners();
    } else {
      _lockPiece();
    }
  }

  // ──────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────

  void _lockPiece() {
    if (_currentPiece == null) return;
    _board.lockPiece(_currentPiece!, _pieceX, _pieceY);

    final cleared = _board.clearLines();
    if (cleared.isNotEmpty) {
      _updateScore(cleared.length);
      _updateLevel();
    }

    _holdUsedThisTurn = false;
    _spawnNextPiece();
    notifyListeners();
  }

  void _spawnNextPiece() {
    _currentPiece = _nextPiece ?? Tetromino.random();
    _nextPiece = Tetromino.random();

    // Spawn at top-center
    _pieceX = (GameBoard.width - _currentPiece!.currentShape[0].length) ~/ 2;
    _pieceY = 0;

    if (!_board.canPlacePiece(_currentPiece!, _pieceX, _pieceY)) {
      gameOver();
    }
  }

  void _updateScore(int clearedCount) {
    _linesCleared += clearedCount;
    _score += ScoringSystem.calculateScore(clearedCount, _level);

    if (_score > _highScore) {
      _highScore = _score;
    }
  }

  void _updateLevel() {
    final newLevel = (_linesCleared ~/ 10) + 1;
    if (newLevel > _level) {
      _level = newLevel;
    }
  }

  int calculateFallInterval() {
    const baseFallSpeed = 1000;
    const minFallSpeed = 100;
    final interval = baseFallSpeed - (_level - 1) * 50;
    return interval.clamp(minFallSpeed, baseFallSpeed);
  }

  List<Offset> _getWallKicks(int fromRotation, TetrominoType type) {
    // Simplified SRS wall kicks
    if (type == TetrominoType.I) {
      return const [
        Offset(-2, 0),
        Offset(2, 0),
        Offset(-2, -1),
        Offset(2, 1),
      ];
    }
    return const [
      Offset(-1, 0),
      Offset(1, 0),
      Offset(-1, -1),
      Offset(1, -1),
      Offset(0, 1),
    ];
  }
}
