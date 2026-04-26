import 'database_helper.dart';
import 'category.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insert(Category category) async {
    final db = await _dbHelper.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<List<Category>> getByType(String type) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'id ASC',  // Prefer older (lower id) when deduplicating
    );
    var list = List.generate(maps.length, (i) => Category.fromMap(maps[i]));
    // Deduplicate savings categories by name (fixes double-insert from v3+v4 migration)
    if (type == 'savings' && list.length > 3) {
      final seen = <String>{};
      list = list.where((c) {
        if (seen.contains(c.name)) return false;
        seen.add(c.name);
        return true;
      }).toList();
    }
    return list;
  }

  Future<Category?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<int> update(Category category) async {
    final db = await _dbHelper.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    // Check if category is being used in transactions
    final transactionCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE categoryId = ?',
      [id],
    );

    if ((transactionCount.first['count'] as int) > 0) {
      throw Exception('Cannot delete category that has transactions');
    }

    return await db.delete(
      'categories',
      where: 'id = ? AND isDefault = 0',
      whereArgs: [id],
    );
  }
}