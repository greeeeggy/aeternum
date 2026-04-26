import 'package:flutter/material.dart';
import '../models/tetris_theme.dart';

class ScorePanel extends StatelessWidget {
  final int score;
  final int highScore;
  final int level;
  final int linesCleared;

  const ScorePanel({
    required this.score,
    required this.highScore,
    required this.level,
    required this.linesCleared,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: TetrisTheme.icePanel(radius: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _scoreItem('SCORE', score.toString()),
          _divider(),
          _scoreItem('BEST', highScore.toString()),
          _divider(),
          _scoreItem('LEVEL', level.toString()),
          _divider(),
          _scoreItem('LINES', linesCleared.toString()),
        ],
      ),
    );
  }

  Widget _scoreItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: TetrisTheme.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: TetrisTheme.bannerBox(radius: 6),
          child: Text(
            value,
            style: const TextStyle(
              color: TetrisTheme.textLight,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: TetrisTheme.panelLight.withOpacity(0.5),
      );
}
