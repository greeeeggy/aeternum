import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'budget_planner_theme.dart';
import 'budget_service.dart';
import 'category.dart';
import 'savings_goal.dart';
import 'savings_goal_repository.dart';
import 'transaction.dart' as bp_transaction;
import 'transaction_repository.dart';
import 'category_repository.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BudgetService _budgetService = BudgetService();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final TransactionRepository _transactionRepo = TransactionRepository();
  final SavingsGoalRepository _goalRepo = SavingsGoalRepository();

  static const _keyPeriod = 'budget_planner_dashboard_period';

  String _selectedPeriod = 'monthly';
  DateTime _currentDate = DateTime.now();

  Map<String, DateTime>? _periodDates;
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _netBalance = 0.0;
  double _totalSavings = 0.0;
  Map<String, dynamic>? _budgetStatus;
  List<Map<String, dynamic>> _topCategories = [];
  List<Map<String, dynamic>> _topSavings = [];
  List<bp_transaction.Transaction> _dayTransactions = [];
  bp_transaction.Transaction? _largestExpense;
  Category? _largestExpenseCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersistedPeriod();
  }

  Future<void> _loadPersistedPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPeriod = prefs.getString(_keyPeriod) ?? 'monthly';
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _budgetService.generateRecurringTransactions();

      _periodDates = _budgetService.calculatePeriodDates(_selectedPeriod, focusedDate: _currentDate);
      final startDate = _periodDates!['startDate']!;
      final endDate = _periodDates!['endDate']!;

      final income = await _budgetService.getTotalIncome(startDate, endDate);
      final expenses = await _budgetService.getTotalExpenses(startDate, endDate);
      final balance = await _budgetService.getNetBalance(startDate, endDate);
      final savings = await _budgetService.getTotalSavings(startDate, endDate);
      final budgetStatus = await _budgetService.getOverallBudgetStatus(startDate, endDate);
      final topCategories = await _budgetService.getTopSpendingCategories(startDate, endDate, 5);
      final topSavings = await _budgetService.getTopSavingsCategories(startDate, endDate, 5);
      final largestExpense = await _budgetService.getLargestExpense(startDate, endDate);

      Category? largestExpenseCategory;
      if (largestExpense != null) {
        largestExpenseCategory = await _categoryRepo.getById(largestExpense.categoryId);
      }

      List<bp_transaction.Transaction> dayTransactions = [];
      if (_selectedPeriod == 'daily') {
        dayTransactions = await _transactionRepo.getByDateRange(startDate, endDate);
      }

      setState(() {
        _totalIncome = income;
        _totalExpenses = expenses;
        _netBalance = balance;
        _totalSavings = savings;
        _budgetStatus = budgetStatus;
        _topCategories = topCategories;
        _topSavings = topSavings;
        _dayTransactions = dayTransactions;
        _largestExpense = largestExpense;
        _largestExpenseCategory = largestExpenseCategory;
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

  void _changePeriod() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select Period',
            style: TextStyle(color: BPTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['daily', 'weekly', 'monthly'].map((p) {
            return ListTile(
              title: Text(
                p[0].toUpperCase() + p.substring(1),
                style: TextStyle(color: BPTheme.textPrimary),
              ),
              leading: Radio<String>(
                value: p,
                groupValue: _selectedPeriod,
                activeColor: BPTheme.accentIndigo,
                onChanged: (value) async {
                  setState(() => _selectedPeriod = value!);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_keyPeriod, _selectedPeriod);
                  if (mounted) Navigator.pop(context);
                  _loadData();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _navigatePeriod(bool forward) {
    setState(() {
      if (_selectedPeriod == 'daily') {
        _currentDate = forward
            ? _currentDate.add(const Duration(days: 1))
            : _currentDate.subtract(const Duration(days: 1));
      } else if (_selectedPeriod == 'weekly') {
        _currentDate = forward
            ? _currentDate.add(const Duration(days: 7))
            : _currentDate.subtract(const Duration(days: 7));
      } else if (_selectedPeriod == 'monthly') {
        _currentDate = forward
            ? DateTime(_currentDate.year, _currentDate.month + 1, 1)
            : DateTime(_currentDate.year, _currentDate.month - 1, 1);
      }
    });
    _loadData();
  }

  String _getPeriodLabel() {
    if (_periodDates == null) return '';
    final startDate = _periodDates!['startDate']!;
    final endDate = _periodDates!['endDate']!;

    if (_selectedPeriod == 'daily') {
      return DateFormat('MMM d, y').format(startDate);
    } else if (_selectedPeriod == 'weekly') {
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}';
    } else {
      return DateFormat('MMMM yyyy').format(startDate);
    }
  }

  void _showCalendar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BPTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: TableCalendar(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _currentDate,
            selectedDayPredicate: (day) => isSameDay(day, _currentDate),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: BPTheme.accentIndigo,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: BPTheme.accentIndigo.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(color: BPTheme.textPrimary),
              weekendTextStyle: TextStyle(color: BPTheme.textSecondary),
              outsideTextStyle: TextStyle(color: BPTheme.textDisabled),
              selectedTextStyle: const TextStyle(color: Colors.white),
              todayTextStyle: const TextStyle(color: Colors.white),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: BPTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: BPTheme.accentIndigo),
              rightChevronIcon: Icon(Icons.chevron_right, color: BPTheme.accentIndigo),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: BPTheme.textSecondary),
              weekendStyle: TextStyle(color: BPTheme.textSecondary),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() => _currentDate = selectedDay);
              Navigator.pop(context);
              _loadData();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: BPTheme.accentIndigo),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: BPTheme.accentIndigo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            _buildBalanceCard(),
            const SizedBox(height: 16),
            if (_budgetStatus?['hasBudget'] == true) ...[
              _buildBudgetProgressCard(),
              const SizedBox(height: 16),
            ],
            _buildIncomeExpenseCard(),
            const SizedBox(height: 16),
            _buildTopCategoriesCard(),
            const SizedBox(height: 16),
            _buildSavingsCard(),
            const SizedBox(height: 16),
            if (_selectedPeriod == 'daily') ...[
              _buildDayTransactionsCard(),
              const SizedBox(height: 16),
            ],
            if (_largestExpense != null) _buildLargestExpenseCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BPTheme.surfaceEl,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BPTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: BPTheme.accentIndigo),
            onPressed: () => _navigatePeriod(false),
          ),
          Expanded(
            child: InkWell(
              onTap: _changePeriod,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  Text(
                    _getPeriodLabel(),
                    style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _selectedPeriod.toUpperCase(),
                    style: TextStyle(
                      color: BPTheme.accent,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: BPTheme.accentIndigo),
            onPressed: () => _navigatePeriod(true),
          ),
          IconButton(
            icon: Icon(Icons.calendar_month_rounded, color: BPTheme.accentIndigo),
            onPressed: _showCalendar,
            tooltip: 'Pick date',
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final isPositive = _netBalance >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? BPTheme.gradientPositive
              : BPTheme.gradientNegative,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: '₱',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: _netBalance.abs().toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgressCard() {
    final status = _budgetStatus!;
    final percentage = status['percentage'] as double;
    final isOverBudget = status['isOverBudget'] as bool;
    final isNearLimit = status['isNearLimit'] as bool;

    Color progressColor = BPTheme.accentIndigo;
    if (isOverBudget) {
      progressColor = BPTheme.expense;
    } else if (isNearLimit) {
      progressColor = BPTheme.warning;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Progress',
                style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: progressColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 14,
              backgroundColor: BPTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spent',
                      style: TextStyle(color: BPTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '₱${status['spent'].toStringAsFixed(2)}',
                    style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Budget',
                      style: TextStyle(color: BPTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '₱${status['budgetAmount'].toStringAsFixed(2)}',
                    style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isOverBudget) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BPTheme.expense.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BPTheme.expense.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: BPTheme.expense, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Over budget by ₱${(status['spent'] - status['budgetAmount']).toStringAsFixed(2)}',
                      style: TextStyle(color: BPTheme.expense, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isNearLimit) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BPTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BPTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: BPTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remaining: ₱${status['remaining'].toStringAsFixed(2)}',
                      style: TextStyle(color: BPTheme.warning, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: BPTheme.income,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.trending_up_rounded,
                        color: BPTheme.income, size: 20),
                    const SizedBox(width: 6),
                    Text('Income',
                        style: TextStyle(
                            color: BPTheme.textSecondary, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₱${_totalIncome.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: BPTheme.income,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: BPTheme.divider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: BPTheme.expense,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.trending_down_rounded,
                          color: BPTheme.expense, size: 20),
                      const SizedBox(width: 6),
                      Text('Expenses',
                          style: TextStyle(
                              color: BPTheme.textSecondary, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${_totalExpenses.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: BPTheme.expense,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Spending Categories',
            style: TextStyle(
              color: BPTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_topCategories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded,
                        size: 48,
                        color: BPTheme.accentIndigo.withOpacity(0.4)),
                    const SizedBox(height: 8),
                    Text('No expenses yet',
                        style: TextStyle(
                            color: BPTheme.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            ..._topCategories.map((category) => FutureBuilder<Category?>(
              future: _categoryRepo.getById(category['categoryId']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final cat = snapshot.data!;
                final amount = category['amount'] as double;
                final percentage = _totalExpenses > 0
                    ? (amount / _totalExpenses * 100)
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(cat.color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(cat.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.name,
                                style: TextStyle(
                                    color: BPTheme.textPrimary,
                                    fontSize: 14)),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 7,
                                backgroundColor: BPTheme.divider,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(cat.color),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: BPTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: BPTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            )),
        ],
      ),
    );
  }

  Widget _buildLargestExpenseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Largest Expense',
            style: TextStyle(
              color: BPTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_largestExpenseCategory != null)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(_largestExpenseCategory!.color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(_largestExpenseCategory!.icon,
                        style: const TextStyle(fontSize: 24)),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_largestExpenseCategory != null)
                      Text(
                        _largestExpenseCategory!.name,
                        style: TextStyle(
                            color: BPTheme.textPrimary, fontSize: 16),
                      ),
                    if (_largestExpense!.notes != null)
                      Text(
                        _largestExpense!.notes!,
                        style: TextStyle(
                            color: BPTheme.textSecondary, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      DateFormat('MMM d, y').format(_largestExpense!.date),
                      style: TextStyle(
                          color: BPTheme.textDisabled, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '₱${_largestExpense!.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: BPTheme.expense,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.savings_rounded,
                      color: BPTheme.accentAmber, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Savings',
                    style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '₱${_totalSavings.toStringAsFixed(2)}',
                style: TextStyle(
                  color: BPTheme.accentAmber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_topSavings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No savings yet',
                  style:
                      TextStyle(color: BPTheme.textSecondary),
                ),
              ),
            )
          else
            ..._topSavings.map((entry) => _buildSavingsTile(entry)),
        ],
      ),
    );
  }

  Widget _buildSavingsTile(Map<String, dynamic> entry) {
    final amount = entry['amount'] as double;
    final percentage =
        _totalSavings > 0 ? (amount / _totalSavings * 100) : 0.0;
    final goalId = entry['goalId'] as int?;
    final categoryId = entry['categoryId'] as int?;

    if (goalId != null) {
      return FutureBuilder<SavingsGoal?>(
        future: _goalRepo.getById(goalId),
        builder: (context, snapshot) {
          final goal = snapshot.data;
          final iconColor =
              goal != null ? Color(goal.color) : BPTheme.accentAmber;
          return _savingsTileRow(
            icon: goal?.icon ?? '🎯',
            label: goal?.name ?? 'Goal',
            amount: amount,
            percentage: percentage,
            iconColor: iconColor,
          );
        },
      );
    }

    return FutureBuilder<Category?>(
      future:
          categoryId != null ? _categoryRepo.getById(categoryId) : Future.value(null),
      builder: (context, snapshot) {
        final cat = snapshot.data;
        return _savingsTileRow(
          icon: cat?.icon ?? '💰',
          label: cat?.name ?? 'Savings',
          amount: amount,
          percentage: percentage,
          iconColor:
              cat != null ? Color(cat.color) : BPTheme.accentAmber,
        );
      },
    );
  }

  Widget _savingsTileRow({
    required String icon,
    required String label,
    required double amount,
    required double percentage,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: BPTheme.textPrimary, fontSize: 14)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 6,
                    backgroundColor: BPTheme.divider,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    color: BPTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: BPTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayTransactionTile(bp_transaction.Transaction tx) {
    final isIncome = tx.type == 'income';
    final isSavings = tx.type == 'savings';
    final color = isIncome
        ? BPTheme.income
        : isSavings
            ? BPTheme.savings
            : BPTheme.expense;
    final sign = (isIncome || isSavings) ? '+' : '-';

    Widget iconContainer(String emoji, Color c) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        );

    Widget buildRow({
      required String icon,
      required String label,
      Color iconColor = const Color(0xFF64748B),
      String? note,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            // colored left strip
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            iconContainer(icon, iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: BPTheme.textPrimary, fontSize: 14)),
                  if (note != null && note.isNotEmpty)
                    Text(note,
                        style: TextStyle(
                            color: BPTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(
              '$sign₱${tx.amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (tx.goalId != null) {
      return FutureBuilder<SavingsGoal?>(
        future: _goalRepo.getById(tx.goalId!),
        builder: (context, snapshot) {
          final goal = snapshot.data;
          return buildRow(
            icon: goal?.icon ?? '🎯',
            label: goal?.name ?? 'Goal',
            iconColor: goal != null ? Color(goal.color) : BPTheme.accentAmber,
            note: tx.notes,
          );
        },
      );
    }

    return FutureBuilder<Category?>(
      future: _categoryRepo.getById(tx.categoryId),
      builder: (context, snapshot) {
        final cat = snapshot.data;
        return buildRow(
          icon: cat?.icon ?? '💰',
          label: cat?.name ?? 'Unknown',
          iconColor: cat != null ? Color(cat.color) : BPTheme.textSecondary,
          note: tx.notes,
        );
      },
    );
  }

  Widget _buildDayTransactionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Transactions",
            style: TextStyle(
              color: BPTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_dayTransactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No transactions for this day',
                  style: TextStyle(color: BPTheme.textSecondary),
                ),
              ),
            )
          else
            ..._dayTransactions.map((tx) => _buildDayTransactionTile(tx)),
        ],
      ),
    );
  }
}
