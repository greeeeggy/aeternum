import 'database_helper.dart';
import 'budget.dart';

class BudgetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(Budget budget) async {
    final db = await _dbHelper.database;
    return await db.insert('budgets', budget.toMap());
  }

  Future<List<Budget>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  Future<List<Budget>> getActiveBudgets(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'isEnabled = 1 AND startDate <= ? AND endDate >= ?',
      whereArgs: [endDate.toIso8601String(), startDate.toIso8601String()],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  Future<Budget?> getOverallBudget(DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'categoryId IS NULL AND isEnabled = 1 AND startDate <= ? AND endDate >= ?',
      whereArgs: [endDate.toIso8601String(), startDate.toIso8601String()],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<Budget?> getCategoryBudget(int categoryId, DateTime startDate, DateTime endDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'categoryId = ? AND isEnabled = 1 AND startDate <= ? AND endDate >= ?',
      whereArgs: [categoryId, endDate.toIso8601String(), startDate.toIso8601String()],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<Budget?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<int> update(Budget budget) async {
    final db = await _dbHelper.database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}