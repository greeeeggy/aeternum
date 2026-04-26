import 'package:flutter/material.dart';
import '../logic/tetris_game_logic.dart';
import '../models/tetris_theme.dart';

class ControlsWidget extends StatelessWidget {
  final TetrisGameLogic gameLogic;

  const ControlsWidget({required this.gameLogic, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // ← adjust this SizedBox below to change the gap between the two pads
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Left: D-pad ──
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _directionButton(Icons.chevron_left_rounded, gameLogic.movePieceLeft),
                  const SizedBox(width: 16),
                  _directionButton(Icons.chevron_right_rounded, gameLogic.movePieceRight),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _directionButton(
                      Icons.keyboard_arrow_down_rounded, gameLogic.movePieceDown),
                ],
              ),
            ],
          ),

          const SizedBox(width: 40), // ← change this value to adjust the gap

          // ── Right: action buttons ──
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  _actionButton(
                    icon: Icons.refresh_rounded,
                    label: 'ROTATE',
                    onTap: gameLogic.rotatePieceClockwise,
                  ),
                  const SizedBox(width: 16),
                  _actionButton(
                    icon: Icons.download_rounded,
                    label: 'DROP',
                    onTap: gameLogic.hardDrop,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionButton(
                    icon: Icons.save_rounded,
                    label: 'HOLD',
                    onTap: gameLogic.holdPiece,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: TetrisTheme.bannerBox(radius: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TetrisTheme.textLight, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: TetrisTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: TetrisTheme.bannerBox(radius: 12),
        child: Icon(icon, color: TetrisTheme.textLight, size: 30),
      ),
    );
  }
}
