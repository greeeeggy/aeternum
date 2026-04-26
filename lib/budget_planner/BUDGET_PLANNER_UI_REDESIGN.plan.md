# Budget Planner UI Redesign Plan
> **Scope:** UI-only changes — color schemes, containers, buttons, AppBar, BottomNav, form fields, cards, dialogs, progress indicators. **Zero logic changes.**

---

## 1. Design Philosophy

The current UI suffers from:
- Overuse of `Colors.black` and `Colors.grey[850/900]` everywhere (flat, dull, monotone)
- Inconsistent theming — `BPColors` in `budget_planner_theme.dart` exists but is barely used; all screens hardcode raw color literals
- Plain blue FABs and buttons with no visual personality
- No dark/light mode toggle — everything is forced dark

The redesign introduces:
- **"Aurora Finance"** — a vibrant, modern palette with teal-to-indigo gradients, warm amber accents, and real visual hierarchy
- **Light Mode default** with a proper dark mode toggle in the AppBar
- Consistent use of `BPTheme` helper (extended `budget_planner_theme.dart`) across all screens
- Glassmorphism-style cards with subtle borders and soft shadows
- Pill-shaped and gradient-fill buttons replacing flat grey blocks
- Animated gradient `LinearProgressIndicator` replacements with rounded caps

---

## 2. New Color System — `budget_planner_theme.dart`

Completely replace `BPColors` and `BPStyles` with an extended `BPTheme` class that supports light/dark mode. The color tokens below are the target palette.

### Light Mode Colors
```
background:        #F0F4FF   (soft lavender-white)
surface:           #FFFFFF   (pure white cards)
surfaceElevated:   #EEF2FF   (slightly blue-tinted white)
divider:           #E2E8F0

accent (teal):     #00BFA6
accentIndigo:      #6366F1
accentAmber:       #F59E0B
accentPink:        #EC4899   (new — used for FABs)

income:            #10B981   (emerald green)
expense:           #EF4444   (clear red)
savings:           #F59E0B   (amber-gold)
warning:           #FB923C

textPrimary:       #1E293B   (rich dark navy — not pure black)
textSecondary:     #64748B
textDisabled:      #CBD5E1
```

### Dark Mode Colors
```
background:        #0D1117
surface:           #161B22
surfaceElevated:   #1F2937
divider:           #2D3748

accent (teal):     #00BFA6   (same)
accentIndigo:      #818CF8
accentAmber:       #FCD34D
accentPink:        #F472B6

income:            #34D399
expense:           #F87171
savings:           #FCD34D
warning:           #FB923C

textPrimary:       #F1F5F9
textSecondary:     #94A3B8
textDisabled:      #475569
```

### Gradient Definitions (shared light/dark)
```
gradientBalance (positive):  #10B981 → #059669
gradientBalance (negative):  #EF4444 → #DC2626
gradientHeader:              #6366F1 → #8B5CF6
gradientSavings:             #F59E0B → #D97706
gradientAnalytics:           #7C3AED → #6366F1
```

---

## 3. `BPTheme` Class Restructure

Replace the current static-only `BPColors`/`BPStyles` classes with a theme-aware system:

```dart
class BPTheme {
  static bool isDark = false; // toggled by the dark mode switch in AppBar

  static Color get background    => isDark ? Color(0xFF0D1117)  : Color(0xFFF0F4FF);
  static Color get surface       => isDark ? Color(0xFF161B22)  : Color(0xFFFFFFFF);
  static Color get surfaceEl     => isDark ? Color(0xFF1F2937)  : Color(0xFFEEF2FF);
  static Color get divider       => isDark ? Color(0xFF2D3748)  : Color(0xFFE2E8F0);
  static Color get textPrimary   => isDark ? Color(0xFFF1F5F9)  : Color(0xFF1E293B);
  static Color get textSecondary => isDark ? Color(0xFF94A3B8)  : Color(0xFF64748B);
  static Color get textDisabled  => isDark ? Color(0xFF475569)  : Color(0xFFCBD5E1);
  static Color get accent        => const Color(0xFF00BFA6);
  static Color get accentIndigo  => isDark ? Color(0xFF818CF8)  : Color(0xFF6366F1);
  static Color get accentAmber   => isDark ? Color(0xFFFCD34D)  : Color(0xFFF59E0B);
  static Color get accentPink    => isDark ? Color(0xFFF472B6)  : Color(0xFFEC4899);
  static Color get income        => isDark ? Color(0xFF34D399)  : Color(0xFF10B981);
  static Color get expense       => isDark ? Color(0xFFF87171)  : Color(0xFFEF4444);
  static Color get savings       => isDark ? Color(0xFFFCD34D)  : Color(0xFFF59E0B);
  // ... card decoration, field decoration, appbar theme getters etc.
}
```

> **Important:** `BPTheme.isDark` is a simple `static bool`. The toggle in `BudgetPlannerPage` calls `setState(() => BPTheme.isDark = !BPTheme.isDark)` which triggers a full rebuild of the subtree. No state management library required.

---

## 4. Dark Mode Toggle — `budget_planner_page.dart`

Add a `ValueNotifier<bool>` or a simple `bool _isDark` in `_BudgetPlannerPageState` and pass it down.

**AppBar changes:**
- Background: gradient `#6366F1 → #8B5CF6` (light) / `#161B22` (dark)
- Title: `"Budget Planner"` with font weight 700, size 20
- Add `IconButton` with `Icons.dark_mode` / `Icons.light_mode` **right of title** — this is the new dark mode toggle
- Keep the existing `Icons.category` and `Icons.repeat` action buttons, just update their colors to `Colors.white`

**BottomNavigationBar changes:**
- Replace `BottomNavigationBar` with a custom `Container` + `Row` of nav items
- Background: `BPTheme.surface` with top border `divider`
- Selected item: pill background `accentIndigo.withOpacity(0.15)` + icon in `accentIndigo` + label in `accentIndigo`
- Unselected: icon and label in `textSecondary`
- No elevation, borderRadius `24` on pill
- OR: use `NavigationBar` (Material 3) with `indicatorColor: BPTheme.accentIndigo.withOpacity(0.2)`

---

## 5. Card Design System

All `Container` cards across all screens follow the same new decoration — extracted to `BPTheme.cardDecoration`:

```
color:         BPTheme.surface
borderRadius:  BorderRadius.circular(20)
border:        Border.all(color: BPTheme.divider, width: 1)
boxShadow:     [
  BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),   // light shadow
  BoxShadow(color: Color(0x05FFFFFF), blurRadius: 1, offset: Offset(0, -1)),   // top highlight
]
```

Dark mode shadow: `Color(0x40000000)` instead of `0x0A000000`.

---

## 6. Screen-by-Screen Changes

### 6.1 `dashboard_screen.dart`

**Period Selector Bar**
- Background: `BPTheme.surfaceEl` with `borderRadius: 16`, border `BPTheme.divider`
- Chevron buttons: `accentIndigo` color
- Period label: `textPrimary`, bold 16
- Sub-label (MONTHLY/WEEKLY/DAILY): `accent` color, 11px, letter spacing 1.2

**Balance Card (`_buildBalanceCard`)**
- Gradient: `#10B981 → #059669` (positive) / `#EF4444 → #DC2626` (negative) — keep existing logic
- Add subtle white inner border: `Border.all(color: Colors.white.withOpacity(0.15))`
- "Net Balance" label: white 70% opacity, 14px
- Amount: white, 38px, bold, add `₱` symbol with slightly smaller font (26px)
- Add a small coin/wallet icon top-right corner at 20% white opacity

**Budget Progress Card (`_buildBudgetProgressCard`)**
- Container: `BPTheme.cardDecoration`
- Progress bar: `LinearProgressIndicator` → replace with `ClipRRect(borderRadius: 10)` wrapping `LinearProgressIndicator(minHeight: 14)` — already done, just ensure `strokeCap`-equivalent rounded look
- Progress colors remain the same logic (blue → orange → red)
- Percentage badge: pill shape, color matches progress color, `borderRadius: 20`
- Warning/near-limit banners: rounded-12 border containers, keep existing logic colors

**Income/Expense Card (`_buildIncomeExpenseCard`)**
- Background: `BPTheme.cardDecoration`
- Income column: small green dot indicator + green `#10B981` amount
- Expense column: small red dot indicator + red `#EF4444` amount
- Divider: vertical line with `BPTheme.divider`
- Icons: replace `Icons.arrow_downward` with `Icons.trending_down` (income), `Icons.trending_up` (expense)

**Top Categories Card**
- Category progress bars: use each category's own color (existing logic keeps this)
- Card background: `BPTheme.cardDecoration`
- Empty state: replace grey icon with a soft indigo-tinted empty state illustration style

**Savings Card**
- Title row: `Icons.savings` icon in `accentAmber` before "Savings" text
- Total amount: `accentAmber` bold

**Day Transactions Card**
- Transaction tiles: income = green left border accent strip, savings = amber, expense = red
- Add `Container(width: 4, height: 40, color: color, borderRadius: BorderRadius.circular(2))` as leftmost element

**Calendar BottomSheet (`_showCalendar`)**
- Background: `BPTheme.surface`
- `selectedDecoration`: `accentIndigo` circle
- `todayDecoration`: `accentIndigo.withOpacity(0.3)` circle
- Text colors: all updated to `BPTheme.textPrimary` / `BPTheme.textSecondary`

**Period Dialog**
- `backgroundColor`: `BPTheme.surface`
- Radio `activeColor`: `BPTheme.accentIndigo`
- Title/text colors: `BPTheme.textPrimary`

---

### 6.2 `budget_planner_page.dart` (AppBar + Nav)

See Section 4 above. Exact implementation:

```dart
// In build():
appBar: AppBar(
  title: ShaderMask(
    shaderCallback: (bounds) => LinearGradient(
      colors: [Colors.white, Colors.white70],
    ).createShader(bounds),
    child: const Text('Budget Planner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
  ),
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _isDark
            ? [Color(0xFF161B22), Color(0xFF1F2937)]
            : [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      ),
    ),
  ),
  backgroundColor: Colors.transparent,
  elevation: 0,
  actions: [
    IconButton(
      icon: Icon(_isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.white),
      onPressed: () => setState(() {
        _isDark = !_isDark;
        BPTheme.isDark = _isDark; // sync global
      }),
      tooltip: _isDark ? 'Light Mode' : 'Dark Mode',
    ),
    IconButton(icon: Icon(Icons.category_rounded, color: Colors.white), ...),
    IconButton(icon: Icon(Icons.repeat_rounded, color: Colors.white), ...),
  ],
),
```

---

### 6.3 `transactions_screen.dart`

**Search Bar**
- Background: `BPTheme.surfaceEl`
- Focused border: `BPTheme.accent` 1.5px
- Search icon: `BPTheme.accentIndigo`
- Filter button: gradient background `accentIndigo → accent`, white icon

**Transaction Tiles (`_buildTransactionTile`)**
- Container: `BPTheme.cardDecoration` with `margin: EdgeInsets.only(bottom: 10)`
- Left icon container: keep category color logic, `borderRadius: 14`
- Amount color: income=`BPTheme.income`, savings=`BPTheme.savings`, expense=`BPTheme.expense`
- Add colored left-side accent bar (4px wide strip matching amount color)
- Date text: `BPTheme.textDisabled`, 11px

**FAB**
- Replace `backgroundColor: Colors.blue` with gradient FAB:
  ```dart
  FloatingActionButton(
    backgroundColor: Colors.transparent,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF00BFA6)]),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.add, color: Colors.white),
    ),
    ...
  )
  ```

**Filter Dialog**
- Background: `BPTheme.surface`
- FilterChip/ChoiceChip selected color: `BPTheme.accentIndigo.withOpacity(0.2)`, selected border `accentIndigo`
- Reset/Apply button: text color `BPTheme.accentIndigo`

**Delete confirmation dialogs**
- Background: `BPTheme.surface`
- Cancel button: `BPTheme.textSecondary`
- Delete button: `BPTheme.expense`

---

### 6.4 `budgets_screen.dart`

**Budget Cards (`_buildBudgetCard`)**
- Container: `BPTheme.cardDecoration`
- Overall budget icon container: gradient background `accentIndigo.withOpacity(0.15)` with `accentIndigo` icon
- Progress bar: 14px height, `borderRadius: 10`, rounded caps
- Over-budget text: `BPTheme.expense`
- `more_vert` icon: `BPTheme.textSecondary`

**Bottom Sheet (edit/delete menu)**
- Background: `BPTheme.surface`
- Icon colors: edit=`BPTheme.accentIndigo`, delete=`BPTheme.expense`

**FAB**: same gradient treatment as transactions screen

**Empty State**
- Icon: `BPTheme.accentIndigo.withOpacity(0.3)`
- Primary text: `BPTheme.textPrimary`
- Secondary text: `BPTheme.textSecondary`

---

### 6.5 `savings_screen.dart`

**TabBar**
- Background: `BPTheme.surface`
- `indicatorColor`: `BPTheme.accentAmber`
- `labelColor`: `BPTheme.accentAmber`
- `unselectedLabelColor`: `BPTheme.textSecondary`

**Total Savings Card**
- Keep amber gradient: `#FF8F00 → #FFC107` (light mode)
- Dark mode variant: `#B45309 → #D97706`
- Text: dark navy in light mode, white in dark mode

**Breakdown Tiles**
- Container: `BPTheme.cardDecoration`
- Progress bars: each uses the category/goal's own color (no change to logic)

**Goal Selector Chips**
- Unselected: `BPTheme.surfaceEl`, border `BPTheme.divider`
- Selected: goal color `.withOpacity(0.2)` bg, goal color border 1.5px

**Goal Detail Banner (header)**
- Keep dynamic gradient using `goal.color` (logic unchanged)
- Add `BoxShadow` for depth

**Circular Progress**
- `CircularProgressIndicator` stroke color: `goal.color` (unchanged)
- Track color: `BPTheme.divider`

**Breakdown Card / Motivation Card**
- Background: `BPTheme.surfaceEl` instead of `const Color(0xFF2C2C2E)`

**"Create My First Goal" button**
- Keep green color logic (`Color(0xFF10B981)`)

**Goal Complete Card**
- Keep amber gradient — it's already vibrant

---

### 6.6 `analytics_screen.dart`

**Period Selector**
- Same treatment as dashboard period selector

**Total Spending Card**
- Replace plain purple gradient with: `#7C3AED → #6366F1` (more vivid violet)
- Add subtle pattern overlay (not required, optional)

**Trend Chart Container**
- Background: `BPTheme.cardDecoration`
- Chart line color: replace hardcoded `Colors.blueAccent` with `BPTheme.accentIndigo`
- Touch tooltip: background `BPTheme.surfaceEl`, border `BPTheme.divider`
- Grid lines: `BPTheme.divider`
- Axis labels: `BPTheme.textSecondary`, 10px

**Category Breakdown Cards**
- Container: `BPTheme.cardDecoration`
- Keep each category's own color for progress bars (unchanged logic)

---

### 6.7 `add_transaction_screen.dart`

**AppBar**
- Same gradient treatment as `BudgetPlannerPage` AppBar (consistent)
- Back arrow: `Colors.white`

**Type Selector Buttons (`_buildTypeButton`)**
- Unselected: `BPTheme.surfaceEl`, border transparent, icon/text `BPTheme.textSecondary`
- Selected income: `BPTheme.income.withOpacity(0.15)` bg, `BPTheme.income` border + icon + text
- Selected expense: `BPTheme.expense.withOpacity(0.15)` bg, `BPTheme.expense` border + icon + text
- Selected savings: `BPTheme.savings.withOpacity(0.15)` bg, `BPTheme.savings` border + icon + text
- Shape: `borderRadius: 16`, taller padding `vertical: 18`

**Amount Field**
- Background: `BPTheme.surfaceEl`
- Focused border: `BPTheme.accent` 1.5px
- `₱` prefix: bold, `BPTheme.accent`
- Text: `BPTheme.textPrimary`

**Category Dropdown Container**
- Background: `BPTheme.surfaceEl`
- Dropdown popup: `BPTheme.surface`
- Text: `BPTheme.textPrimary`

**Date Picker Row**
- Container: `BPTheme.cardDecoration`
- Calendar icon: `BPTheme.accentIndigo`
- Date text: `BPTheme.textPrimary`

**Notes Field**
- Background: `BPTheme.surfaceEl`
- Hint: `BPTheme.textDisabled`

**Save Button**
- Replace `backgroundColor: Colors.blue` with gradient:
  ```
  gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF00BFA6)])
  borderRadius: 16
  height: 56
  ```
- Text: white, bold 16

**DatePicker Theme**
- `colorScheme.primary`: `BPTheme.accentIndigo`
- `colorScheme.surface`: `BPTheme.surface`

---

### 6.8 `add_budget_screen.dart`

**AppBar**: gradient treatment (same as add_transaction)

**Budget Type Toggle Buttons**
- Same approach as type selector: selected indigo with indigo border, unselected surfaceEl

**Amount Field, Dropdowns**: same field style as add_transaction

**Save Button**: gradient (indigo → teal)

---

### 6.9 `add_category_screen.dart` & `add_savings_goal_screen.dart` & `recurring_transactions_screen.dart` & `add_recurring_transaction_screen.dart`

Apply the same rules universally:
- AppBar: gradient header
- All form fields: `BPTheme.field()` style (updated to use new surfaceEl fill + accent focus border)
- All containers/cards: `BPTheme.cardDecoration`
- All primary action buttons: gradient pill button
- All destructive buttons: `BPTheme.expense` color
- All cancel/secondary buttons: `BPTheme.textSecondary`
- All dialogs/bottom sheets: `BPTheme.surface` background

---

### 6.10 `categories_screen.dart`

**AppBar**: gradient
**Category tiles**: `BPTheme.cardDecoration`, icon container `borderRadius: 14`
**"Default" badge**: `BPTheme.accentIndigo.withOpacity(0.15)` pill background, `BPTheme.accentIndigo` text
**"Custom" badge**: `BPTheme.accentAmber.withOpacity(0.15)` pill, `BPTheme.accentAmber` text
**PopupMenu**: `BPTheme.surface` background
**FAB**: gradient

---

## 7. Global Form Field Style Update — `budget_planner_theme.dart`

Update `BPStyles.field()` to use the new light/dark tokens:

```dart
static InputDecoration field(String hint, {String? prefix}) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: BPTheme.textDisabled),
  prefixText: prefix,
  prefixStyle: TextStyle(color: BPTheme.textSecondary, fontWeight: FontWeight.w600),
  filled: true,
  fillColor: BPTheme.surfaceEl,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: BPTheme.divider),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: BPTheme.accent, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: BPTheme.expense),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: BPTheme.expense, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
);
```

---

## 8. Shared Gradient Button Widget

Add a `BPGradientButton` helper in `budget_planner_theme.dart` to avoid repetition:

```dart
class BPGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color> gradientColors;

  const BPGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.gradientColors = const [Color(0xFF6366F1), Color(0xFF00BFA6)],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: onPressed == null
              ? [Colors.grey, Colors.grey]
              : gradientColors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onPressed != null ? [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.35),
              blurRadius: 12,
              offset: Offset(0, 4),
            )
          ] : [],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
```

---

## 9. SnackBar Styling

Update all `SnackBar` calls to use themed snackbars:
- Success (delete confirmed, saved): `backgroundColor: BPTheme.income`, white text
- Error: `backgroundColor: BPTheme.expense`, white text
- Info: `backgroundColor: BPTheme.accentIndigo`, white text
- `behavior: SnackBarBehavior.floating`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`

---

## 10. `CircularProgressIndicator` Loading States

All loading spinners:
- Replace `Colors.blue` with `BPTheme.accentIndigo`
- Exception: savings screen spinner keeps `BPTheme.savings` (amber) where already set

---

## 11. Implementation Order

1. **`budget_planner_theme.dart`** — Add `BPTheme` class, update `BPStyles.field()`, add `BPGradientButton`
2. **`budget_planner_page.dart`** — AppBar gradient + dark mode toggle + `NavigationBar` update
3. **`dashboard_screen.dart`** — All cards, period selector, dialogs, calendar sheet
4. **`transactions_screen.dart`** — Search bar, tiles, FAB, filter dialog
5. **`budgets_screen.dart`** — Budget cards, FAB, bottom sheet, empty state
6. **`savings_screen.dart`** — TabBar, overview tab, goal selector chips, goal detail
7. **`analytics_screen.dart`** — Spending card, chart, category cards
8. **`add_transaction_screen.dart`** — AppBar, type buttons, fields, date, save button
9. **`add_budget_screen.dart`** — AppBar, type toggle, fields, save button
10. **`categories_screen.dart`** — AppBar, tiles, badges, FAB
11. **`add_category_screen.dart`**, **`add_savings_goal_screen.dart`**, **`add_recurring_transaction_screen.dart`**, **`recurring_transactions_screen.dart`** — AppBar + fields + save buttons only

---

## 12. What is NOT Changed

- All business logic, data fetching, state management, repositories, services
- Widget tree structure (no widgets added or removed — only decoration/style properties changed)
- All navigation logic
- All `FutureBuilder` / `AnimationController` / `ConfettiController` logic
- All `TableCalendar` configuration except color values
- All `fl_chart` chart data / axis logic / touch logic — only color values updated
- All form validators
- Database layer (`database_helper.dart`, all repositories)
- All model classes (`budget.dart`, `transaction.dart`, etc.)

---

## 13. Quick Reference: Color Swap Table

| Before (hardcoded) | After (token) |
|---|---|
| `Colors.black` (AppBar bg) | `BPTheme gradient` |
| `Colors.grey[900]` (scaffold bg) | `BPTheme.background` |
| `Colors.grey[850]` (card bg) | `BPTheme.surface` + shadow |
| `Colors.grey[700]` (progress track) | `BPTheme.divider` |
| `Colors.grey[400]` (secondary text) | `BPTheme.textSecondary` |
| `Colors.grey[600]` (hint text) | `BPTheme.textDisabled` |
| `Colors.white` (primary text) | `BPTheme.textPrimary` |
| `Colors.blue` (FAB, button, spinner) | `BPTheme.accentIndigo` or gradient |
| `Colors.green` (income) | `BPTheme.income` |
| `Colors.red` (expense) | `BPTheme.expense` |
| `Colors.amber` (savings) | `BPTheme.savings` |
| `Colors.orange` (warning) | `BPTheme.warning` |
| `Colors.purple[700/500]` (analytics) | `Color(0xFF7C3AED) → Color(0xFF6366F1)` |
