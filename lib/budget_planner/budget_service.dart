import 'transaction.dart';
import 'transaction_repository.dart';
import 'budget_repository.dart';
import 'recurring_transaction_repository.dart';

class BudgetService {
  final TransactionRepository _transactionRepo = TransactionRepository();
  final BudgetRepository _budgetRepo = BudgetRepository();
  final RecurringTransactionRepository _recurringRepo = RecurringTransactionRepository();

  // Calculate date ranges based on period type
  Map<String, DateTime> calculatePeriodDates(String periodType, {DateTime? customStartDate, DateTime? customEndDate, DateTime? focusedDate}) {
    final ref = focusedDate ?? DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (periodType) {
      case 'daily':
        startDate = DateTime(ref.year, ref.month, ref.day);
        endDate = DateTime(ref.year, ref.month, ref.day, 23, 59, 59);
        break;
      case 'weekly':
        // Start from Monday of the week containing ref
        startDate = ref.subtract(Duration(days: ref.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'monthly':
        startDate = DateTime(ref.year, ref.month, 1);
        endDate = DateTime(ref.year, ref.month + 1, 0, 23, 59, 59);
        break;
      case 'yearly':
        startDate = DateTime(ref.year, 1, 1);
        endDate = DateTime(ref.year, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        if (customStartDate == null || customEndDate == null) {
          throw Exception('Custom period requires start and end dates');
        }
        startDate = DateTime(customStartDate.year, customStartDate.month, customStartDate.day);
        endDate = DateTime(customEndDate.year, customEndDate.month, customEndDate.day, 23, 59, 59);
        break;
      default:
        throw Exception('Invalid period type');
    }

    return {'startDate': startDate, 'endDate': endDate};
  }

  // Get total expenses for a period
  Future<double> getTotalExpenses(DateTime startDate, DateTime endDate) async {
    final totals = await _transactionRepo.getTotalsByType(startDate, endDate);
    return totals['expense'] ?? 0.0;
  }

  // Get total income for a period
  Future<double> getTotalIncome(DateTime startDate, DateTime endDate) async {
    final totals = await _transactionRepo.getTotalsByType(startDate, endDate);
    return totals['income'] ?? 0.0;
  }

  // Get total savings for a period
  Future<double> getTotalSavings(DateTime startDate, DateTime endDate) async {
    final totals = await _transactionRepo.getTotalsByType(startDate, endDate);
    return totals['savings'] ?? 0.0;
  }

  // Calculate net balance (income - expenses - savings)
  Future<double> getNetBalance(DateTime startDate, DateTime endDate) async {
    final income = await getTotalIncome(startDate, endDate);
    final expenses = await getTotalExpenses(startDate, endDate);
    final savings = await getTotalSavings(startDate, endDate);
    return income - expenses - savings;
  }

  // Get budget status for overall budget
  Future<Map<String, dynamic>> getOverallBudgetStatus(DateTime startDate, DateTime endDate) async {
    final budget = await _budgetRepo.getOverallBudget(startDate, endDate);
    if (budget == null) {
      return {
        'hasBudget': false,
        'budgetAmount': 0.0,
        'spent': 0.0,
        'remaining': 0.0,
        'percentage': 0.0,
        'isOverBudget': false,
        'isNearLimit': false,
      };
    }

    final spent = await getTotalExpenses(startDate, endDate);
    final remaining = budget.amount - spent;
    final percentage = (spent / budget.amount * 100).clamp(0, 100);
    final isOverBudget = spent > budget.amount;
    final isNearLimit = percentage >= 80 && !isOverBudget;

    return {
      'hasBudget': true,
      'budgetAmount': budget.amount,
      'spent': spent,
      'remaining': remaining,
      'percentage': percentage,
      'isOverBudget': isOverBudget,
      'isNearLimit': isNearLimit,
    };
  }

  // Get budget status for a specific category
  Future<Map<String, dynamic>> getCategoryBudgetStatus(
      int categoryId,
      DateTime startDate,
      DateTime endDate,
      ) async {
    final budget = await _budgetRepo.getCategoryBudget(categoryId, startDate, endDate);
    if (budget == null) {
      return {
        'hasBudget': false,
        'budgetAmount': 0.0,
        'spent': 0.0,
        'remaining': 0.0,
        'percentage': 0.0,
        'isOverBudget': false,
        'isNearLimit': false,
      };
    }

    final transactions = await _transactionRepo.getByCategoryAndDateRange(
      categoryId,
      startDate,
      endDate,
    );

    final spent = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    final remaining = budget.amount - spent;
    final percentage = budget.amount > 0 ? (spent / budget.amount * 100).clamp(0, 100) : 0.0;
    final isOverBudget = spent > budget.amount;
    final isNearLimit = percentage >= 80 && !isOverBudget;

    return {
      'hasBudget': true,
      'budgetAmount': budget.amount,
      'spent': spent,
      'remaining': remaining,
      'percentage': percentage,
      'isOverBudget': isOverBudget,
      'isNearLimit': isNearLimit,
    };
  }

  // Generate transactions from recurring rules
  Future<void> generateRecurringTransactions() async {
    final recurringTransactions = await _recurringRepo.getActive();
    final now = DateTime.now();

    for (var recurring in recurringTransactions) {
      DateTime nextDate = recurring.lastGeneratedDate ?? recurring.startDate;

      // If this is the first time generating, start from startDate
      if (recurring.lastGeneratedDate == null) {
        nextDate = recurring.startDate;
      } else {
        // Otherwise, calculate the next occurrence after lastGeneratedDate
        nextDate = _calculateNextOccurrence(recurring.lastGeneratedDate!, recurring.frequency, recurring.excludedDays);
      }

      // Generate all missed transactions up to today
      while (nextDate.isBefore(now) || _isSameDay(nextDate, now)) {
        // Check if we've passed the end date
        if (recurring.endDate != null && nextDate.isAfter(recurring.endDate!)) {
          break;
        }

        // For daily recurring, check if this day is excluded
        if (recurring.frequency == 'daily' && recurring.excludedDays != null) {
          if (recurring.excludedDays!.contains(nextDate.weekday)) {
            // Skip this day, move to next
            nextDate = _calculateNextOccurrence(nextDate, recurring.frequency, recurring.excludedDays);
            continue;
          }
        }

        // Check if transaction already exists for this date and recurring rule
        final existingTransactions = await _transactionRepo.getByDateRange(
          DateTime(nextDate.year, nextDate.month, nextDate.day),
          DateTime(nextDate.year, nextDate.month, nextDate.day, 23, 59, 59),
        );

        final alreadyExists = existingTransactions.any((t) =>
        t.name == recurring.name &&
            t.amount == recurring.amount &&
            t.type == recurring.type &&
            t.categoryId == recurring.categoryId
        );

        if (!alreadyExists) {
          // Create the transaction
          final transaction = Transaction(
            name: recurring.name,
            amount: recurring.amount,
            type: recurring.type,
            categoryId: recurring.categoryId,
            date: nextDate,
            recurringTransactionId: recurring.id,
          );

          await _transactionRepo.insert(transaction);
        }

        // Update lastGeneratedDate
        final updatedRecurring = recurring.copyWith(lastGeneratedDate: nextDate);
        await _recurringRepo.update(updatedRecurring);

        // Move to next occurrence
        nextDate = _calculateNextOccurrence(nextDate, recurring.frequency, recurring.excludedDays);
      }
    }
  }

  // Helper function to calculate next occurrence based on frequency
  DateTime _calculateNextOccurrence(DateTime currentDate, String frequency, List<int>? excludedDays) {
    switch (frequency) {
      case 'daily':
        DateTime nextDate = currentDate.add(const Duration(days: 1));
        // If daily and has excluded days, keep incrementing until we find a non-excluded day
        if (excludedDays != null) {
          while (excludedDays.contains(nextDate.weekday)) {
            nextDate = nextDate.add(const Duration(days: 1));
          }
        }
        return nextDate;
      case 'weekly':
        return currentDate.add(const Duration(days: 7));
      case 'monthly':
        int nextMonth = currentDate.month + 1;
        int nextYear = currentDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        // Handle day overflow (e.g., Jan 31 -> Feb 28/29)
        int day = currentDate.day;
        int lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (day > lastDayOfNextMonth) {
          day = lastDayOfNextMonth;
        }
        return DateTime(nextYear, nextMonth, day);
      default:
        return currentDate;
    }
  }

  // Helper function to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Get spending by category
  Future<Map<int, double>> getSpendingByCategory(DateTime startDate, DateTime endDate) async {
    return await _transactionRepo.getExpensesByCategory(startDate, endDate);
  }

  // Get top savings — grouped by goal (when set) then by category, for display.
  // Each entry has: 'amount', and either 'goalId' (int) or 'categoryId' (int).
  Future<List<Map<String, dynamic>>> getTopSavingsCategories(
      DateTime startDate,
      DateTime endDate,
      int limit,
      ) async {
    final transactions = await _transactionRepo.getByDateRange(startDate, endDate);
    final savingsTx = transactions.where((t) => t.type == 'savings');

    // Group by goalId (if set) or categoryId
    final Map<String, double> grouped = {};
    final Map<String, Map<String, dynamic>> meta = {};

    for (final t in savingsTx) {
      final String key = t.goalId != null ? 'goal_${t.goalId}' : 'cat_${t.categoryId}';
      grouped[key] = (grouped[key] ?? 0.0) + t.amount;
      if (!meta.containsKey(key)) {
        if (t.goalId != null) {
          meta[key] = {'goalId': t.goalId};
        } else {
          meta[key] = {'categoryId': t.categoryId};
        }
      }
    }

    final sorted = grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => {
      ...meta[e.key]!,
      'amount': e.value,
    }).toList();
  }

  // Get top spending categories
  Future<List<Map<String, dynamic>>> getTopSpendingCategories(
      DateTime startDate,
      DateTime endDate,
      int limit,
      ) async {
    final expenses = await _transactionRepo.getExpensesByCategory(startDate, endDate);
    final sorted = expenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => {
      'categoryId': e.key,
      'amount': e.value,
    }).toList();
  }

  // Get largest expense in period
  Future<Transaction?> getLargestExpense(DateTime startDate, DateTime endDate) async {
    final transactions = await _transactionRepo.getByDateRange(startDate, endDate);
    final expenses = transactions.where((t) => t.type == 'expense').toList();

    if (expenses.isEmpty) return null;

    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    return expenses.first;
  }
}