import 'package:flutter/material.dart';
import 'budget_planner_theme.dart';
import 'recurring_transaction.dart';
import 'category.dart';
import 'recurring_transaction_repository.dart';
import 'category_repository.dart';
import 'add_recurring_transaction_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final RecurringTransactionRepository _recurringRepo =
      RecurringTransactionRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  List<RecurringTransaction> _recurringTransactions = [];
  Map<int, Category> _categories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final recurring = await _recurringRepo.getAll();
      final categories = await _categoryRepo.getAll();

      final categoryMap = <int, Category>{};
      for (var category in categories) {
        categoryMap[category.id!] = category;
      }

      setState(() {
        _recurringTransactions = recurring;
        _categories = categoryMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error loading data: $e'),
        );
      }
    }
  }

  void _navigateToAdd(
      {RecurringTransaction? transaction}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecurringTransactionScreen(
            transaction: transaction),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _toggleActive(
      RecurringTransaction transaction) async {
    try {
      await _recurringRepo.update(
        transaction.copyWith(isActive: !transaction.isActive),
      );
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error: $e'),
        );
      }
    }
  }

  Future<void> _delete(RecurringTransaction transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Recurring Transaction',
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete this recurring transaction?',
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
        await _recurringRepo.delete(transaction.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            BPTheme.snackSuccess(
                'Recurring transaction deleted'),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            BPTheme.snackError('Error: $e'),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(title: 'Recurring Transactions'),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: BPTheme.accentIndigo))
          : _recurringTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat_rounded,
                          size: 80,
                          color: BPTheme.accentIndigo
                              .withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No recurring transactions',
                        style: TextStyle(
                            color: BPTheme.textSecondary,
                            fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first one',
                        style: TextStyle(
                            color: BPTheme.textDisabled,
                            fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: BPTheme.accentIndigo,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _recurringTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction =
                          _recurringTransactions[index];
                      final category =
                          _categories[transaction.categoryId];
                      return _buildRecurringTile(
                          transaction, category);
                    },
                  ),
                ),
      floatingActionButton: BPGradientFab(
        onPressed: () => _navigateToAdd(),
      ),
    );
  }

  Widget _buildRecurringTile(RecurringTransaction transaction,
      Category? category) {
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome ? BPTheme.income : BPTheme.expense;
    final isActive = transaction.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BPTheme.cardDecoration.copyWith(
        border: Border.all(
          color: isActive ? BPTheme.divider : BPTheme.divider.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          // left accent strip
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: isActive
                  ? amountColor
                  : BPTheme.textDisabled,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (category != null)
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Color(category.color).withOpacity(
                    isActive ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: TextStyle(
                    fontSize: 22,
                    color: isActive ? null : BPTheme.textDisabled,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.name ?? 'Unknown',
                    style: TextStyle(
                      color: isActive
                          ? BPTheme.textPrimary
                          : BPTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? BPTheme.accentIndigo
                                  .withOpacity(0.12)
                              : BPTheme.divider,
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Text(
                          transaction.frequency.toUpperCase(),
                          style: TextStyle(
                            color: isActive
                                ? BPTheme.accentIndigo
                                : BPTheme.textDisabled,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? BPTheme.income.withOpacity(0.12)
                              : BPTheme.divider,
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Paused',
                          style: TextStyle(
                            color: isActive
                                ? BPTheme.income
                                : BPTheme.textDisabled,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (transaction.notes != null &&
                      transaction.notes!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      transaction.notes!,
                      style: TextStyle(
                          color: BPTheme.textSecondary,
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}₱${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isActive
                        ? amountColor
                        : BPTheme.textDisabled,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _actionIconButton(
                      icon: isActive
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: BPTheme.accentIndigo,
                      onTap: () =>
                          _toggleActive(transaction),
                    ),
                    const SizedBox(width: 4),
                    _actionIconButton(
                      icon: Icons.edit_rounded,
                      color: BPTheme.accentAmber,
                      onTap: () => _navigateToAdd(
                          transaction: transaction),
                    ),
                    const SizedBox(width: 4),
                    _actionIconButton(
                      icon: Icons.delete_rounded,
                      color: BPTheme.expense,
                      onTap: () => _delete(transaction),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
