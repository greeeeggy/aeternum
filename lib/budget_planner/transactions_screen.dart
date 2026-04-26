import 'package:flutter/material.dart';
import 'budget_planner_theme.dart';
import 'transaction.dart' as bp_transaction;
import 'category.dart';
import 'transaction_repository.dart';
import 'category_repository.dart';
import 'savings_goal.dart';
import 'savings_goal_repository.dart';
import 'add_transaction_screen.dart';
import 'joint_savings_service.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionRepository _transactionRepo = TransactionRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final SavingsGoalRepository _goalRepo = SavingsGoalRepository();

  List<bp_transaction.Transaction> _transactions = [];
  List<bp_transaction.Transaction> _filteredTransactions = [];
  Map<int, Category> _categories = {};
  Map<int, SavingsGoal> _goals = {};
  bool _isLoading = true;

  String? _filterType;
  int? _filterCategoryId;
  String _searchQuery = '';
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await _transactionRepo.getAll();
      final categories = await _categoryRepo.getAll();
      final goals = await _goalRepo.getAll();

      final categoryMap = <int, Category>{};
      for (var category in categories) {
        categoryMap[category.id!] = category;
      }

      final goalMap = <int, SavingsGoal>{};
      for (var goal in goals) {
        goalMap[goal.id!] = goal;
      }

      setState(() {
        _transactions = transactions;
        _categories = categoryMap;
        _goals = goalMap;
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error loading transactions: $e'),
        );
      }
    }
  }

  void _applyFiltersAndSort() {
    var filtered = List<bp_transaction.Transaction>.from(_transactions);

    if (_filterType != null) {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }
    if (_filterCategoryId != null) {
      filtered = filtered.where((t) => t.categoryId == _filterCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) =>
              t.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false)
          .toList();
    }

    switch (_sortBy) {
      case 'amount':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'category':
        filtered.sort((a, b) {
          final catA = _categories[a.categoryId]?.name ?? '';
          final catB = _categories[b.categoryId]?.name ?? '';
          return catA.compareTo(catB);
        });
        break;
      case 'date':
      default:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
    }

    setState(() => _filteredTransactions = filtered);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Filter & Sort',
            style: TextStyle(
                color: BPTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type',
                  style:
                      TextStyle(color: BPTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('All', _filterType == null,
                      () => setState(() => _filterType = null)),
                  _filterChip('Income', _filterType == 'income',
                      () => setState(() => _filterType = 'income')),
                  _filterChip('Expense', _filterType == 'expense',
                      () => setState(() => _filterType = 'expense')),
                  _filterChip('Savings', _filterType == 'savings',
                      () => setState(() => _filterType = 'savings')),
                ],
              ),
              const SizedBox(height: 16),
              Text('Sort By',
                  style:
                      TextStyle(color: BPTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('Date', _sortBy == 'date',
                      () => setState(() => _sortBy = 'date')),
                  _filterChip('Amount', _sortBy == 'amount',
                      () => setState(() => _sortBy = 'amount')),
                  _filterChip('Category', _sortBy == 'category',
                      () => setState(() => _sortBy = 'category')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterType = null;
                _filterCategoryId = null;
                _sortBy = 'date';
                _applyFiltersAndSort();
              });
              Navigator.pop(context);
            },
            child: Text('Reset',
                style: TextStyle(color: BPTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _applyFiltersAndSort();
              Navigator.pop(context);
            },
            child: Text('Apply',
                style: TextStyle(color: BPTheme.accentIndigo)),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected
              ? BPTheme.accentIndigo.withOpacity(0.15)
              : BPTheme.surfaceEl,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? BPTheme.accentIndigo : BPTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? BPTheme.accentIndigo : BPTheme.textSecondary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _deleteTransaction(bp_transaction.Transaction transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Transaction',
            style: TextStyle(
                color: BPTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete this transaction?',
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
    if (confirm == true) await _doDelete(transaction);
  }

  /// Performs the actual delete: Firestore (if joint) + SQLite, then refreshes.
  Future<void> _doDelete(bp_transaction.Transaction transaction) async {
    try {
      // Joint transaction: delete from Firestore first
      if (transaction.categoryId == -1 || transaction.categoryId == -2) {
        final pairId = transaction.jointPairId;
        final targetId = transaction.jointTargetId;
        final firestoreTxId = transaction.jointFirestoreTxId;
        if (pairId != null && targetId != null && firestoreTxId != null) {
          final service = JointSavingsService();
          if (transaction.categoryId == -1) {
            await service.deleteSavingsTransaction(
              pairId: pairId, potId: targetId, txId: firestoreTxId,
            );
          } else {
            await service.deleteGoalTransaction(
              pairId: pairId, goalId: targetId, txId: firestoreTxId,
            );
          }
        }
      }
      await _transactionRepo.delete(transaction.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackSuccess('Transaction deleted'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error deleting transaction: $e'),
        );
      }
    }
  }

  void _navigateToAddTransaction(
      {bp_transaction.Transaction? transaction}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionScreen(transaction: transaction),
      ),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: BPTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFiltersAndSort();
                      });
                    },
                    style: TextStyle(color: BPTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      hintStyle:
                          TextStyle(color: BPTheme.textDisabled),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: BPTheme.accentIndigo),
                      filled: true,
                      fillColor: BPTheme.surfaceEl,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: BPTheme.accent, width: 1.5),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: BPTheme.gradientButton,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list_rounded,
                        color: Colors.white),
                    onPressed: _showFilterDialog,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: BPTheme.accentIndigo))
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 80,
                                color: BPTheme.accentIndigo
                                    .withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                  color: BPTheme.textSecondary,
                                  fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first transaction',
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
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction =
                                _filteredTransactions[index];
                            final category =
                                _categories[transaction.categoryId];
                            final goal = transaction.goalId != null
                                ? _goals[transaction.goalId!]
                                : null;
                            return _buildTransactionTile(
                                transaction, category,
                                goal: goal);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: BPGradientFab(
        onPressed: () => _navigateToAddTransaction(),
      ),
    );
  }

  Widget _buildTransactionTile(
      bp_transaction.Transaction transaction, Category? category,
      {SavingsGoal? goal}) {
    final isIncome = transaction.type == 'income';
    final isSavings = transaction.type == 'savings';
    final amountColor = isIncome
        ? BPTheme.income
        : isSavings
            ? BPTheme.savings
            : BPTheme.expense;

    return Dismissible(
      key: Key(transaction.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: BPTheme.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: BPTheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Delete Transaction',
                style: TextStyle(
                    color: BPTheme.textPrimary,
                    fontWeight: FontWeight.w700)),
            content: Text(
              'Are you sure you want to delete this transaction?',
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
          await _doDelete(transaction);
        }
        return false; // always false — list refreshes via _loadData()
      },
      onDismissed: (_) {},
      child: InkWell(
        onTap: () =>
            _navigateToAddTransaction(transaction: transaction),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BPTheme.cardDecoration,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // colored left accent strip — stretches to full tile height
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: amountColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // icon
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: goal != null
                          ? Color(goal.color).withOpacity(0.2)
                          : category != null
                              ? Color(category.color).withOpacity(0.2)
                              : BPTheme.surfaceEl,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        goal?.icon ?? category?.icon ?? '💰',
                        style: const TextStyle(fontSize: 22),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          goal?.name ?? category?.name ?? transaction.name ?? 'Unknown',
                          style: TextStyle(
                            color: BPTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Joint transaction label — categoryId -1 = joint savings, -2 = joint goal
                        if (transaction.categoryId == -1 || transaction.categoryId == -2) ...[  
                          const SizedBox(height: 2),
                          Text(
                            transaction.categoryId == -1
                                ? (transaction.type == 'savings' ? 'Joint Savings contribution' : 'Joint Savings withdrawal')
                                : (transaction.type == 'savings' ? 'Joint Goal contribution' : 'Joint Goal withdrawal'),
                            style: TextStyle(
                                color: BPTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                        if (transaction.notes != null &&
                            transaction.notes!.isNotEmpty) ...[  
                          const SizedBox(height: 2),
                          Text(
                            transaction.notes!,
                            style: TextStyle(
                                color: BPTheme.textSecondary,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d, y').format(transaction.date),
                          style: TextStyle(
                              color: BPTheme.textDisabled, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      '${isIncome || isSavings ? '+' : '-'}₱${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
