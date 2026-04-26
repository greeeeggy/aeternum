import 'package:flutter/material.dart';
import 'budget_planner_theme.dart';
import 'budget.dart';
import 'category.dart';
import 'budget_repository.dart';
import 'category_repository.dart';
import 'budget_service.dart';
import 'add_budget_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final BudgetRepository _budgetRepo = BudgetRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final BudgetService _budgetService = BudgetService();

  List<Budget> _budgets = [];
  Map<int, Category> _categories = {};
  Map<int, Map<String, dynamic>> _budgetStatuses = {};
  bool _isLoading = true;
  String _selectedPeriod = 'monthly';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final dates =
          _budgetService.calculatePeriodDates(_selectedPeriod);
      final budgets = await _budgetRepo.getActiveBudgets(
          dates['startDate']!, dates['endDate']!);
      final categories = await _categoryRepo.getAll();

      final categoryMap = <int, Category>{};
      for (var category in categories) {
        categoryMap[category.id!] = category;
      }

      final statusMap = <int, Map<String, dynamic>>{};
      for (var budget in budgets) {
        if (budget.categoryId != null) {
          final status = await _budgetService.getCategoryBudgetStatus(
            budget.categoryId!,
            dates['startDate']!,
            dates['endDate']!,
          );
          statusMap[budget.id!] = status;
        }
      }

      setState(() {
        _budgets = budgets;
        _categories = categoryMap;
        _budgetStatuses = statusMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error loading budgets: $e'),
        );
      }
    }
  }

  void _navigateToAddBudget({Budget? budget}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBudgetScreen(budget: budget),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Budget',
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete this budget?',
          style: TextStyle(color: BPTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: BPTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: BPTheme.expense)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _budgetRepo.delete(budget.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            BPTheme.snackSuccess('Budget deleted'),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            BPTheme.snackError('Error deleting budget: $e'),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: BPTheme.accentIndigo))
          : _budgets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          size: 80,
                          color: BPTheme.accentIndigo.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No budgets set',
                        style: TextStyle(
                            color: BPTheme.textSecondary, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first budget',
                        style: TextStyle(
                            color: BPTheme.textDisabled, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: BPTheme.accentIndigo,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      final budget = _budgets[index];
                      final category = budget.categoryId != null
                          ? _categories[budget.categoryId]
                          : null;
                      final status = _budgetStatuses[budget.id];
                      return _buildBudgetCard(budget, category, status);
                    },
                  ),
                ),
      floatingActionButton: BPGradientFab(
        onPressed: () => _navigateToAddBudget(),
      ),
    );
  }

  Widget _buildBudgetCard(
      Budget budget, Category? category, Map<String, dynamic>? status) {
    final isOverall = budget.categoryId == null;
    final percentage = status?['percentage'] ?? 0.0;
    final isOverBudget = status?['isOverBudget'] ?? false;
    final isNearLimit = status?['isNearLimit'] ?? false;

    Color progressColor = BPTheme.accentIndigo;
    if (isOverBudget) {
      progressColor = BPTheme.expense;
    } else if (isNearLimit) {
      progressColor = BPTheme.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isOverall && category != null)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Color(category.color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(category.icon,
                        style: const TextStyle(fontSize: 20)),
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: BPTheme.accentIndigo.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded,
                      color: BPTheme.accentIndigo),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverall
                          ? 'Overall Budget'
                          : category?.name ?? 'Unknown',
                      style: TextStyle(
                        color: BPTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      budget.periodType.toUpperCase(),
                      style: TextStyle(
                          color: BPTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded,
                    color: BPTheme.textSecondary),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: BPTheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24)),
                    ),
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.edit_rounded,
                                color: BPTheme.accentIndigo),
                            title: Text('Edit',
                                style: TextStyle(
                                    color: BPTheme.textPrimary)),
                            onTap: () {
                              Navigator.pop(context);
                              _navigateToAddBudget(budget: budget);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete_rounded,
                                color: BPTheme.expense),
                            title: Text('Delete',
                                style: TextStyle(
                                    color: BPTheme.expense)),
                            onTap: () {
                              Navigator.pop(context);
                              _deleteBudget(budget);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: BPTheme.divider,
              valueColor:
                  AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₱${status?['spent']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₱${budget.amount.toStringAsFixed(2)}',
                style: TextStyle(
                    color: BPTheme.textSecondary, fontSize: 16),
              ),
            ],
          ),
          if (isOverBudget) ...[
            const SizedBox(height: 8),
            Text(
              'Over budget by ₱${((status?['spent'] ?? 0) - budget.amount).toStringAsFixed(2)}',
              style:
                  TextStyle(color: BPTheme.expense, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
