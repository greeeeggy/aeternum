import 'database_helper.dart';
import 'savings_goal.dart';

class SavingsGoalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(SavingsGoal goal) async {
    final db = await _dbHelper.database;
    return await db.insert('savings_goals', goal.toMap());
  }

  Future<List<SavingsGoal>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('savings_goals', orderBy: 'createdAt DESC');
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  Future<List<SavingsGoal>> getActive() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'savings_goals',
      where: 'completedAt IS NULL',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  Future<SavingsGoal?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'savings_goals',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return SavingsGoal.fromMap(maps.first);
  }

  Future<int> update(SavingsGoal goal) async {
    final db = await _dbHelper.database;
    return await db.update(
      'savings_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'savings_goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
