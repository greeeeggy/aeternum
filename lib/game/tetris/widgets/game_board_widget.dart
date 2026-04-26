import 'package:flutter/material.dart';
import '../logic/game_board.dart';
import '../logic/tetromino.dart';
import '../models/tetromino_shapes.dart';
import '../models/tetris_theme.dart';

class GameBoardWidget extends StatelessWidget {
  final GameBoard board;
  final Tetromino? currentPiece;
  final int pieceX;
  final int pieceY;
  final bool showGhost;

  const GameBoardWidget({
    required this.board,
    this.currentPiece,
    required this.pieceX,
    required this.pieceY,
    this.showGhost = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ghostY = (showGhost && currentPiece != null)
        ? board.calculateGhostY(currentPiece!, pieceX, pieceY)
        : pieceY;

    return Container(
      decoration: TetrisTheme.icePanel(radius: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: GameBoard.width / GameBoard.height,
          child: CustomPaint(
            painter: GameBoardPainter(
              board: board,
              currentPiece: currentPiece,
              pieceX: pieceX,
              pieceY: pieceY,
              ghostY: ghostY,
            ),
          ),
        ),
      ),
    );
  }
}

class GameBoardPainter extends CustomPainter {
  final GameBoard board;
  final Tetromino? currentPiece;
  final int pieceX;
  final int pieceY;
  final int ghostY;

  GameBoardPainter({
    required this.board,
    this.currentPiece,
    required this.pieceX,
    required this.pieceY,
    required this.ghostY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / GameBoard.width;
    final cellHeight = size.height / GameBoard.height;

    // Background — icy blue
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1A5A8A),
    );

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF2470A0).withOpacity(0.6)
      ..strokeWidth = 0.5;

    for (int x = 0; x <= GameBoard.width; x++) {
      canvas.drawLine(Offset(x * cellWidth, 0),
          Offset(x * cellWidth, size.height), gridPaint);
    }
    for (int y = 0; y <= GameBoard.height; y++) {
      canvas.drawLine(Offset(0, y * cellHeight),
          Offset(size.width, y * cellHeight), gridPaint);
    }

    // Locked pieces
    for (int row = 0; row < GameBoard.height; row++) {
      for (int col = 0; col < GameBoard.width; col++) {
        final cell = board.grid[row][col];
        if (cell != null) {
          _drawCell(canvas, col, row, cellWidth, cellHeight,
              TetrominoColors.getColor(cell));
        }
      }
    }

    // Ghost piece
    if (currentPiece != null && ghostY != pieceY) {
      _drawPiece(canvas, currentPiece!, pieceX, ghostY, cellWidth, cellHeight,
          TetrominoColors.getGhostColor(currentPiece!.type));
    }

    // Current piece
    if (currentPiece != null) {
      _drawPiece(canvas, currentPiece!, pieceX, pieceY, cellWidth, cellHeight,
          currentPiece!.color);
    }
  }

  void _drawPiece(Canvas canvas, Tetromino piece, int x, int y,
      double cellWidth, double cellHeight, Color color) {
    final shape = piece.currentShape;
    for (int row = 0; row < shape.length; row++) {
      for (int col = 0; col < shape[row].length; col++) {
        if (shape[row][col] != 0) {
          _drawCell(canvas, x + col, y + row, cellWidth, cellHeight, color);
        }
      }
    }
  }

  void _drawCell(Canvas canvas, int x, int y, double cellWidth,
      double cellHeight, Color color) {
    final rect = Rect.fromLTWH(
      x * cellWidth + 1,
      y * cellHeight + 1,
      cellWidth - 2,
      cellHeight - 2,
    );
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(2));

    // Fill
    canvas.drawRRect(rRect, Paint()..color = color);

    // Top-left highlight
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(GameBoardPainter old) =>
      old.board != board ||
      old.currentPiece != currentPiece ||
      old.pieceX != pieceX ||
      old.pieceY != pieceY ||
      old.ghostY != ghostY;
}
