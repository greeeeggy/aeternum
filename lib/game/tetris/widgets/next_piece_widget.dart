import 'package:flutter/material.dart';
import '../logic/tetromino.dart';
import '../models/tetromino_shapes.dart';
import '../models/tetris_theme.dart';

class NextPieceWidget extends StatelessWidget {
  final Tetromino? nextPiece;

  const NextPieceWidget({this.nextPiece, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: TetrisTheme.icePanel(radius: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: TetrisTheme.bannerBox(radius: 6),
            child: const Text(
              'NEXT',
              style: TextStyle(
                color: TetrisTheme.textLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            height: 60,
            child: nextPiece == null
                ? const SizedBox()
                : CustomPaint(painter: _PiecePainter(piece: nextPiece!)),
          ),
        ],
      ),
    );
  }
}

class HoldPieceWidget extends StatelessWidget {
  final Tetromino? heldPiece;

  const HoldPieceWidget({this.heldPiece, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: TetrisTheme.icePanel(radius: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: TetrisTheme.bannerBox(radius: 6),
            child: const Text(
              'HOLD',
              style: TextStyle(
                color: TetrisTheme.textLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            height: 60,
            child: heldPiece == null
                ? const Center(
                    child: Text('—',
                        style: TextStyle(
                            color: TetrisTheme.textMuted, fontSize: 20)),
                  )
                : CustomPaint(painter: _PiecePainter(piece: heldPiece!)),
          ),
        ],
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  final Tetromino piece;
  _PiecePainter({required this.piece});

  @override
  void paint(Canvas canvas, Size size) {
    final shape = piece.currentShape;
    final rows = shape.length;
    final cols = shape[0].length;
    final cellSize = (size.width / cols).clamp(0.0, size.height / rows);
    final offsetX = (size.width - cellSize * cols) / 2;
    final offsetY = (size.height - cellSize * rows) / 2;
    final color = TetrominoColors.getColor(piece.type);
    final paint = Paint()..color = color;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (shape[r][c] != 0) {
          final rect = Rect.fromLTWH(
            offsetX + c * cellSize + 1,
            offsetY + r * cellSize + 1,
            cellSize - 2,
            cellSize - 2,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            paint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()
              ..color = Colors.white.withOpacity(0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.piece.type != piece.type ||
      old.piece.currentRotation != piece.currentRotation;
}
