import 'database_helper.dart';
import 'recurring_transaction.dart';

class RecurringTransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(RecurringTransaction recurringTransaction) async {
    final db = await _dbHelper.database;
    return await db.insert('recurring_transactions', recurringTransaction.toMap());
  }

  Future<List<RecurringTransaction>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recurring_transactions',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => RecurringTransaction.fromMap(maps[i]));
  }

  Future<List<RecurringTransaction>> getActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recurring_transactions',
      where: 'isActive = 1',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => RecurringTransaction.fromMap(maps[i]));
  }

  Future<RecurringTransaction?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return RecurringTransaction.fromMap(maps.first);
  }

  Future<int> update(RecurringTransaction recurringTransaction) async {
    final db = await _dbHelper.database;
    return await db.update(
      'recurring_transactions',
      recurringTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [recurringTransaction.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}