import 'database_helper.dart';
import 'savings_goal_contribution.dart';

class SavingsGoalContributionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(SavingsGoalContribution contribution) async {
    final db = await _dbHelper.database;
    return await db.insert('savings_goal_contributions', contribution.toMap());
  }

  Future<List<SavingsGoalContribution>> getByGoal(int goalId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'savings_goal_contributions',
      where: 'goalId = ?',
      whereArgs: [goalId],
      orderBy: 'date ASC',
    );
    return maps.map((m) => SavingsGoalContribution.fromMap(m)).toList();
  }

  Future<double> getSumByGoal(int goalId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM savings_goal_contributions WHERE goalId = ?',
      [goalId],
    );
    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return (result.first['total'] as num).toDouble();
  }

  // Returns contributions grouped by week: list of {date, cumulative}
  Future<List<Map<String, dynamic>>> getWeeklyHistory(int goalId) async {
    final contributions = await getByGoal(goalId);
    if (contributions.isEmpty) return [];

    final Map<String, double> weeklyMap = {};
    for (final c in contributions) {
      // Week key: year-weekNumber
      final weekStart = c.date.subtract(Duration(days: c.date.weekday - 1));
      final key = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      weeklyMap[key] = (weeklyMap[key] ?? 0.0) + c.amount;
    }

    double cumulative = 0.0;
    final sorted = weeklyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      cumulative += e.value;
      return {'label': e.key.substring(5), 'amount': e.value, 'cumulative': cumulative, 'date': e.key};
    }).toList();
  }

  // Returns contributions grouped by month
  Future<List<Map<String, dynamic>>> getMonthlyHistory(int goalId) async {
    final contributions = await getByGoal(goalId);
    if (contributions.isEmpty) return [];

    final Map<String, double> monthlyMap = {};
    for (final c in contributions) {
      final key = '${c.date.year}-${c.date.month.toString().padLeft(2, '0')}';
      monthlyMap[key] = (monthlyMap[key] ?? 0.0) + c.amount;
    }

    double cumulative = 0.0;
    final sorted = monthlyMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      cumulative += e.value;
      final parts = e.key.split('-');
      final month = int.parse(parts[1]);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return {'label': months[month - 1], 'amount': e.value, 'cumulative': cumulative, 'date': e.key};
    }).toList();
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'savings_goal_contributions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByGoal(int goalId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'savings_goal_contributions',
      where: 'goalId = ?',
      whereArgs: [goalId],
    );
  }
}
