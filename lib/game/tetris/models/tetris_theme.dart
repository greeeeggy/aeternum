import 'package:flutter/material.dart';

// ── Shared ice-theme constants ──────────────────────────────────
class TetrisTheme {
  static const Color bg = Color(0xFF2B7CB8);
  static const Color panel = Color(0xFF4AA8D8);
  static const Color panelLight = Color(0xFF6EC4E8);
  static const Color banner = Color(0xFF1A5A8A);
  static const Color bannerDark = Color(0xFF0F3A5C);
  static const Color textLight = Colors.white;
  static const Color textMuted = Color(0xFFB8DFF0);
  static const Color gold = Color(0xFFFFCC00);

  static BoxDecoration icePanel({double radius = 16}) => BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: panelLight, width: 2),
        boxShadow: [
          BoxShadow(
            color: bannerDark.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration bannerBox({double radius = 8}) => BoxDecoration(
        color: banner,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: bannerDark, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: bannerDark.withOpacity(0.6),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      );
}
