// lib/screens/tracker/symptom_database_helper.dart

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Database helper for the symptom logging app.
/// This class handles all database operations using sqflite.
class SymptomDatabaseHelper {
  static final SymptomDatabaseHelper instance = SymptomDatabaseHelper._init();

  static Database? _database;

  SymptomDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('symptom_log.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,  -- ISO format YYYY-MM-DD
        moods TEXT,                 -- Comma-separated list
        symptoms TEXT,
        flow TEXT,
        discharge TEXT,
        sex TEXT,
        digestion TEXT,
        other TEXT,
        basal_temperature REAL,
        stress_level REAL,       -- 1-5
        physical_activity TEXT,
        pregnancy_test TEXT,
        ovulation_test TEXT,
        oral_contraceptives TEXT,
        weight REAL,
        notes TEXT
      )
    ''');
  }

  Future<int> saveDailyLog(Map<String, dynamic> log) async {
    final db = await instance.database;
    var prepared = _prepareLogForInsert(log); // your existing method

    // Force convert numeric fields to double (REAL in SQLite)
    prepared['stress_level'] = _toDouble(prepared['stress_level']) ?? 3.0;
    prepared['basal_temperature'] = _toDouble(prepared['basal_temperature']);
    prepared['weight'] = _toDouble(prepared['weight']);

    // Ensure list fields are always comma-separated strings (extra safety)
    final listFields = ['moods', 'symptoms', 'flow', 'discharge', 'sex', 'digestion', 'other'];
    for (String field in listFields) {
      var value = prepared[field];
      if (value is List) {
        prepared[field] = value.join(',');
      } else if (value is String) {
        // already string — fine
      } else if (value != null) {
        prepared[field] = value.toString();
      } else {
        prepared[field] = '';
      }
    }

    return await db.insert(
      'daily_logs',
      prepared,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

// Helper to safely convert to double
  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }



  Future<Map<String, dynamic>?> getLogForDate(String date) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_logs',
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isNotEmpty) {
      return _parseLogFromMap(maps.first);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllLogs({int limit = 100}) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_logs',
      orderBy: 'date DESC',
      limit: limit,
    );

    return maps.map((map) => _parseLogFromMap(map)).toList();
  }

  Future<int> deleteLog(String date) async {
    final db = await instance.database;
    return await db.delete(
      'daily_logs',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Map<String, dynamic> _prepareLogForInsert(Map<String, dynamic> log) {
    Map<String, dynamic> prepared = Map.from(log ?? {});

    final listFields = ['moods', 'symptoms', 'flow', 'discharge', 'sex', 'digestion', 'other'];

    for (String field in listFields) {
      var value = prepared[field];
      if (value is List && value.isNotEmpty) {
        prepared[field] = value.join(',');
      } else if (value is List) {
        prepared[field] = ''; // empty list → empty string
      } else if (value == null) {
        prepared[field] = '';
      } else if (value is! String) {
        prepared[field] = value.toString();
      }
    }

    return prepared;
  }

  Map<String, dynamic> _parseLogFromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsed = Map.from(map);

    List<String> listFields = [
      'moods',
      'symptoms',
      'flow',
      'discharge',
      'sex',
      'digestion',
      'other',
    ];

    for (String field in listFields) {
      if (parsed[field] != null && parsed[field] is String) {
        String value = parsed[field] as String;
        parsed[field] = value.isEmpty ? <String>[] : value.split(',');
      }
    }

    return parsed;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}