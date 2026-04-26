import 'package:flutter/material.dart';
import 'budget_planner_theme.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'recurring_transactions_screen.dart';
import 'analytics_screen.dart';
import 'savings_screen.dart';

class BudgetPlannerPage extends StatefulWidget {
  const BudgetPlannerPage({super.key});

  @override
  State<BudgetPlannerPage> createState() => _BudgetPlannerPageState();
}

class _BudgetPlannerPageState extends State<BudgetPlannerPage> {
  int _currentIndex = 0;
  bool _isDark = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const TransactionsScreen(),
    const BudgetsScreen(),
    const SavingsScreen(),
    const AnalyticsScreen(),
  ];

  void _toggleDarkMode() {
    setState(() {
      _isDark = !_isDark;
      BPTheme.isDark = _isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: AppBar(
        title: const Text(
          'Budget Planner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDark
                  ? BPTheme.gradientHeaderDark
                  : BPTheme.gradientHeader,
            ),
          ),
        ),
        actions: [
          // Dark mode toggle — beside "Budget Planner" title (rightmost first)
          IconButton(
            icon: Icon(
              _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleDarkMode,
            tooltip: _isDark ? 'Light Mode' : 'Dark Mode',
          ),
          IconButton(
            icon: const Icon(Icons.category_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriesScreen(),
                ),
              );
            },
            tooltip: 'Manage Categories',
          ),
          IconButton(
            icon: const Icon(Icons.repeat_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecurringTransactionsScreen(),
                ),
              );
            },
            tooltip: 'Recurring Transactions',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.dashboard_rounded,         label: 'Dashboard'),
      _NavItem(icon: Icons.receipt_long_rounded,      label: 'Transactions'),
      _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Budgets'),
      _NavItem(icon: Icons.savings_rounded,           label: 'Savings'),
      _NavItem(icon: Icons.analytics_rounded,         label: 'Analytics'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: BPTheme.surface,
        border: Border(top: BorderSide(color: BPTheme.divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: BPTheme.isDark
                ? const Color(0x40000000)
                : const Color(0x0A000000),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = i == _currentIndex;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? BPTheme.accentIndigo.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        color: selected
                            ? BPTheme.accentIndigo
                            : BPTheme.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: selected
                              ? BPTheme.accentIndigo
                              : BPTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
