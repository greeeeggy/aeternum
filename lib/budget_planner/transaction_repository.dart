import 'database_helper.dart';
import 'transaction.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(Transaction transaction) async {
    final db = await _dbHelper.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getByCategory(int categoryId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getByCategoryAndDateRange(
      int categoryId,
      DateTime startDate,
      DateTime endDate,
      ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'categoryId = ? AND date >= ? AND date <= ?',
      whereArgs: [
        categoryId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> searchByNotes(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'notes LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<Transaction?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Transaction.fromMap(maps.first);
  }

  Future<int> update(Transaction transaction) async {
    final db = await _dbHelper.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes the local transaction linked to a Firestore joint tx.
  /// Matches by firestoreTxId first (new transactions), then falls back to
  /// matching by targetId + amount + categoryId (old transactions with no stored txId).
  Future<void> deleteByJointTx({
    required String firestoreTxId,
    required String jointTargetId,
    required String potName,
    required double amount,
    required int categoryId, // -1 = savings, -2 = goal
  }) async {
    final db = await _dbHelper.database;
    // Try exact match first (new transactions)
    final deleted = await db.delete(
      'transactions',
      where: 'jointFirestoreTxId = ?',
      whereArgs: [firestoreTxId],
    );
    if (deleted == 0) {
      // Fallback for old transactions (no jointFirestoreTxId stored):
      // match by categoryId + amount + potName (stored in `name` field)
      // Delete only ONE row (oldest) to avoid over-deletion on duplicate amounts
      final rows = await db.query(
        'transactions',
        where: 'categoryId = ? AND amount = ? AND name = ?',
        whereArgs: [categoryId, amount, potName],
        orderBy: 'createdAt ASC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final id = rows.first['id'] as int;
        await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<Map<String, double>> getTotalsByType(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT type, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ?
      GROUP BY type
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    Map<String, double> totals = {'income': 0.0, 'expense': 0.0, 'savings': 0.0};
    for (var row in result) {
      totals[row['type'] as String] = row['total'] as double;
    }
    return totals;
  }

  Future<Map<int, double>> getExpensesByCategory(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT categoryId, SUM(amount) as total
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date <= ?
      GROUP BY categoryId
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    Map<int, double> expenses = {};
    for (var row in result) {
      expenses[row['categoryId'] as int] = row['total'] as double;
    }
    return expenses;
  }

  Future<Map<int, double>> getSavingsByCategory(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT categoryId, SUM(amount) as total
      FROM transactions
      WHERE type = 'savings' AND date >= ? AND date <= ?
      GROUP BY categoryId
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    Map<int, double> savings = {};
    for (var row in result) {
      savings[row['categoryId'] as int] = row['total'] as double;
    }
    return savings;
  }

  // ── Goal progress methods ──────────────────────────────────────────────────

  /// Sum of all savings transactions linked to [goalId].
  Future<double> getSumByGoal(int goalId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'savings' AND goalId = ?",
      [goalId],
    );
    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return (result.first['total'] as num).toDouble();
  }

  /// All savings transactions for [goalId], ordered by date ascending.
  Future<List<Transaction>> getByGoal(int goalId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'transactions',
      where: "type = 'savings' AND goalId = ?",
      whereArgs: [goalId],
      orderBy: 'date ASC, createdAt ASC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  /// Weekly cumulative history for a goal, matching the shape used by the chart.
  Future<List<Map<String, dynamic>>> getWeeklyHistoryByGoal(int goalId) async {
    final transactions = await getByGoal(goalId);
    if (transactions.isEmpty) return [];

    final Map<String, double> weeklyMap = {};
    for (final t in transactions) {
      final weekStart = t.date.subtract(Duration(days: t.date.weekday - 1));
      final key =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      weeklyMap[key] = (weeklyMap[key] ?? 0.0) + t.amount;
    }

    double cumulative = 0.0;
    final sorted = weeklyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      cumulative += e.value;
      return {
        'label': e.key.substring(5),
        'amount': e.value,
        'cumulative': cumulative,
        'date': e.key,
      };
    }).toList();
  }

  /// Monthly cumulative history for a goal, matching the shape used by the chart.
  Future<List<Map<String, dynamic>>> getMonthlyHistoryByGoal(int goalId) async {
    final transactions = await getByGoal(goalId);
    if (transactions.isEmpty) return [];

    final Map<String, double> monthlyMap = {};
    for (final t in transactions) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      monthlyMap[key] = (monthlyMap[key] ?? 0.0) + t.amount;
    }

    double cumulative = 0.0;
    final sorted = monthlyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return sorted.map((e) {
      cumulative += e.value;
      final month = int.parse(e.key.split('-')[1]);
      return {
        'label': months[month - 1],
        'amount': e.value,
        'cumulative': cumulative,
        'date': e.key,
      };
    }).toList();
  }
}