import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert'; // ← ADD THIS

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_data.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_settings (
            id INTEGER PRIMARY KEY,
            pairId TEXT,
            monthsaryDate TEXT,
            anniversaryDate TEXT,
            nicknames TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveUserSettings({
    required String pairId,
    String? monthsaryDate,
    String? anniversaryDate,
    List<String>? nicknames,
  }) async {
    final db = await database;
    final nicknamesJson = nicknames != null ? jsonEncode(nicknames) : '[]';

    final existing = await db.query('user_settings');
    if (existing.isNotEmpty) {
      await db.update(
        'user_settings',
        {
          'pairId': pairId,
          'monthsaryDate': monthsaryDate,
          'anniversaryDate': anniversaryDate,
          'nicknames': nicknamesJson,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    } else {
      await db.insert(
        'user_settings',
        {
          'id': 1,
          'pairId': pairId,
          'monthsaryDate': monthsaryDate,
          'anniversaryDate': anniversaryDate,
          'nicknames': nicknamesJson,
        },
      );
    }
  }

  Future<Map<String, dynamic>?> getUserSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_settings',
      where: 'id = ?',
      whereArgs: [1],
    );

    if (maps.isNotEmpty) {
      final row = maps.first;
      return {
        'pairId': row['pairId'] as String?,
        'monthsaryDate': row['monthsaryDate'] as String?,
        'anniversaryDate': row['anniversaryDate'] as String?,
        'nicknames': row['nicknames'] != null
            ? List<String>.from(jsonDecode(row['nicknames'] as String))
            : [],
      };
    }
    return null;
  }
}