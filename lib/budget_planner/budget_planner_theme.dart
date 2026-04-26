import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BPTheme — "Aurora Finance v2" design system  (Emerald + Navy)
// UI-only: colors, styles, decorations. Zero logic lives here.
// ─────────────────────────────────────────────────────────────────────────────

class BPTheme {
  BPTheme._();

  /// Toggled by the dark-mode switch in BudgetPlannerPage's AppBar.
  /// Any setState() in BudgetPlannerPage re-renders the full subtree.
  static bool isDark = false;

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static Color get background  => isDark ? const Color(0xFF0F172A) : const Color(0xFFE8ECF1);
  static Color get surface     => isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  static Color get surfaceEl   => isDark ? const Color(0xFF1F2937) : const Color(0xFFE0ECFF);
  static Color get divider     => isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);

  // ── Text ───────────────────────────────────────────────────────────────────
  static Color get textPrimary   => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1B2A41);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF486581);
  static Color get textDisabled  => isDark ? const Color(0xFF475569) : const Color(0xFF9FB3C8);

  // ── Brand Accents ──────────────────────────────────────────────────────────
  /// Primary Emerald – growth, active states, primary buttons.
  static const Color accent      = Color(0xFF059669);

  /// Navy – trust, headers, interactive elements.
  /// Light: #1B2A41  |  Dark: #627D98 (Navy-300, legible on dark surface)
  static Color get accentIndigo  => isDark ? const Color(0xFF627D98) : const Color(0xFF1B2A41);

  /// Gold – savings accumulation (NOT green).
  /// Light: #F59E0B  |  Dark: #FBBF24
  static Color get accentAmber   => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  // ── Semantic ───────────────────────────────────────────────────────────────
  /// Income: clearly green but distinct from the Emerald primary brand.
  static Color get income  => isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);

  /// Expense: unambiguous red.
  static Color get expense => isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

  /// Savings: gold — intentionally NOT green so it doesn't clash with income.
  static Color get savings => isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  /// Warning: orange — between gold and red for near-limit states.
  static const Color warning = Color(0xFFF97316);

  // ── Gradients ──────────────────────────────────────────────────────────────
  /// App-bar / header gradient  (light)  — Navy deep → Navy mid
  static const List<Color> gradientHeader     = [Color(0xFF1B2A41), Color(0xFF243B53)];

  /// App-bar / header gradient  (dark)   — very dark navy
  static const List<Color> gradientHeaderDark = [Color(0xFF0F172A), Color(0xFF111827)];

  /// Positive balance / income card
  static const List<Color> gradientPositive   = [Color(0xFF059669), Color(0xFF047857)];

  /// Negative balance / expense card
  static const List<Color> gradientNegative   = [Color(0xFFDC2626), Color(0xFFB91C1C)];

  /// Savings card — gold
  static const List<Color> gradientSavings    = [Color(0xFFF59E0B), Color(0xFFD97706)];

  /// Analytics / total-spending header card
  static const List<Color> gradientAnalytics  = [Color(0xFF059669), Color(0xFF1B2A41)];

  /// Primary action button — Emerald → Navy (mature, bank-level)
  static const List<Color> gradientButton     = [Color(0xFF059669), Color(0xFF1B2A41)];

  // ── Card decoration ────────────────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: divider, width: 1),
    boxShadow: [
      BoxShadow(
        color: isDark ? const Color(0x40000000) : const Color(0x0A000000),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      const BoxShadow(
        color: Color(0x05FFFFFF),
        blurRadius: 1,
        offset: Offset(0, -1),
      ),
    ],
  );

  // ── Form field decoration ──────────────────────────────────────────────────
  static InputDecoration field(String hint, {String? prefix}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: textDisabled),
    prefixText: prefix,
    prefixStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
    filled: true,
    fillColor: surfaceEl,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: accent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: expense),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: expense, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  );

  // ── Themed SnackBar helper ─────────────────────────────────────────────────
  static SnackBar snackSuccess(String msg) => _snack(msg, income);
  static SnackBar snackError(String msg)   => _snack(msg, expense);
  static SnackBar snackInfo(String msg)    => _snack(msg, accentIndigo);

  static SnackBar _snack(String msg, Color bg) => SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    backgroundColor: bg,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BPGradientButton — shared gradient primary action button
// ─────────────────────────────────────────────────────────────────────────────

class BPGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color> gradientColors;
  final double height;

  const BPGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.gradientColors = const [Color(0xFF059669), Color(0xFF1B2A41)],
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BPGradientFab — gradient floating action button
// ─────────────────────────────────────────────────────────────────────────────

class BPGradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final List<Color> colors;

  const BPGradientFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.colors = const [Color(0xFF059669), Color(0xFF1B2A41)],
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BPAppBar — gradient app bar used by all sub-screens
// ─────────────────────────────────────────────────────────────────────────────

PreferredSizeWidget bpAppBar({
  required String title,
  List<Widget>? actions,
  bool showBack = true,
  BuildContext? context,
}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
    ),
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BPTheme.isDark
              ? BPTheme.gradientHeaderDark
              : BPTheme.gradientHeader,
        ),
      ),
    ),
    actions: actions,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Keep the old BPColors / BPStyles names so nothing that might still reference
// them by mistake breaks at compile time.  Both now delegate to BPTheme.
// ─────────────────────────────────────────────────────────────────────────────

@Deprecated('Use BPTheme instead')
class BPColors {
  BPColors._();
  static Color get background      => BPTheme.background;
  static Color get surface         => BPTheme.surface;
  static Color get surfaceElevated => BPTheme.surfaceEl;
  static Color get divider         => BPTheme.divider;
  static const Color accent        = BPTheme.accent;
  static Color get accentIndigo    => BPTheme.accentIndigo;
  static Color get accentAmber     => BPTheme.accentAmber;
  static Color get income          => BPTheme.income;
  static Color get expense         => BPTheme.expense;
  static Color get warning         => BPTheme.warning;
  static Color get textPrimary     => BPTheme.textPrimary;
  static Color get textSecondary   => BPTheme.textSecondary;
  static Color get textDisabled    => BPTheme.textDisabled;
}

@Deprecated('Use BPTheme instead')
class BPStyles {
  BPStyles._();
  static BoxDecoration get card  => BPTheme.cardDecoration;
  static InputDecoration field(String hint, {String? prefix}) =>
      BPTheme.field(hint, prefix: prefix);
}
