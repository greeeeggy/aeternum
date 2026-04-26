// lib/class_schedule/class_schedule_database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'class_model.dart';
import 'schedule_group_model.dart';

class ClassScheduleDatabase {
  static final ClassScheduleDatabase _instance = ClassScheduleDatabase._internal();
  factory ClassScheduleDatabase() => _instance;
  ClassScheduleDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'class_schedules.db');

    return await openDatabase(
      path,
      version: 4, // v4: schedule_groups table + groupId/ownerUid on class_schedules
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE class_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dayOfWeek INTEGER NOT NULL,
        startHour INTEGER NOT NULL,
        startMinute INTEGER NOT NULL,
        endHour INTEGER NOT NULL,
        endMinute INTEGER NOT NULL,
        subjectName TEXT NOT NULL,
        professorName TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        firestoreId TEXT,
        groupId TEXT,
        ownerUid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE schedule_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestoreId TEXT,
        name TEXT NOT NULL,
        localName TEXT,
        ownerUid TEXT NOT NULL
      )
    ''');

    // Create table for UI preferences
    await db.execute('''
      CREATE TABLE ui_preferences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ui_preferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key TEXT UNIQUE NOT NULL,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE class_schedules ADD COLUMN firestoreId TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE class_schedules ADD COLUMN groupId TEXT');
      await db.execute('ALTER TABLE class_schedules ADD COLUMN ownerUid TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schedule_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firestoreId TEXT,
          name TEXT NOT NULL,
          localName TEXT,
          ownerUid TEXT NOT NULL
        )
      ''');
    }
  }

  // ============ Class Schedule Methods ============

  // ============ Schedule Group Methods ============

  Future<int> insertGroup(ScheduleGroup group) async {
    final db = await database;
    return await db.insert('schedule_groups', group.toMap());
  }

  Future<List<ScheduleGroup>> getAllGroups() async {
    final db = await database;
    final maps = await db.query('schedule_groups');
    return maps.map((m) => ScheduleGroup.fromMap(m)).toList();
  }

  Future<void> setGroupFirestoreId(int localId, String firestoreId) async {
    final db = await database;
    await db.update(
      'schedule_groups',
      {'firestoreId': firestoreId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Rename a group locally only (localName — not synced to Firebase)
  Future<void> renameGroupLocally(int localId, String localName) async {
    final db = await database;
    await db.update(
      'schedule_groups',
      {'localName': localName},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertGroupByFirestoreId(ScheduleGroup group) async {
    final db = await database;
    final existing = await db.query(
      'schedule_groups',
      where: 'firestoreId = ?',
      whereArgs: [group.firestoreId],
    );
    final map = group.toMap();
    if (existing.isEmpty) {
      await db.insert('schedule_groups', map);
    } else {
      // Preserve localName — don't overwrite it during sync
      final preservedLocalName = existing.first['localName'] as String?;
      await db.update(
        'schedule_groups',
        {
          'name': group.name,
          'ownerUid': group.ownerUid,
          'firestoreId': group.firestoreId,
          // Only set localName if it wasn't already set by the user
          if (preservedLocalName == null) 'localName': null,
        },
        where: 'firestoreId = ?',
        whereArgs: [group.firestoreId],
      );
    }
  }

  Future<void> deleteGroupById(int localId) async {
    final db = await database;
    // Also delete all classes belonging to this group
    final group = await db.query('schedule_groups', where: 'id = ?', whereArgs: [localId]);
    if (group.isNotEmpty) {
      final fid = group.first['firestoreId'] as String?;
      if (fid != null) {
        await db.delete('class_schedules', where: 'groupId = ?', whereArgs: [fid]);
      }
    }
    await db.delete('schedule_groups', where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> deleteGroupByFirestoreId(String firestoreId) async {
    final db = await database;
    await db.delete('schedule_groups', where: 'firestoreId = ?', whereArgs: [firestoreId]);
    // Also remove all class_schedules that belonged to this group
    await db.delete('class_schedules', where: 'groupId = ?', whereArgs: [firestoreId]);
  }

  // ============ Class Schedule Methods ============

  Future<int> insertClass(ClassSchedule classSchedule) async {
    final db = await database;
    return await db.insert('class_schedules', classSchedule.toMap());
  }

  Future<List<ClassSchedule>> getAllClasses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('class_schedules');
    return maps.map((m) => ClassSchedule.fromMap(m)).toList();
  }

  Future<int> updateClass(ClassSchedule classSchedule) async {
    final db = await database;
    final map = classSchedule.toMap();
    if (classSchedule.firestoreId != null) {
      map['firestoreId'] = classSchedule.firestoreId;
    }
    return await db.update(
      'class_schedules',
      map,
      where: 'id = ?',
      whereArgs: [int.parse(classSchedule.id!)],
    );
  }

  /// Update the firestoreId for a locally-inserted class (by local int id)
  Future<void> setFirestoreId(int localId, String firestoreId) async {
    final db = await database;
    await db.update(
      'class_schedules',
      {'firestoreId': firestoreId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Insert or replace a class identified by its firestoreId (used during sync)
  Future<void> upsertByFirestoreId(ClassSchedule classSchedule) async {
    final db = await database;
    final existing = await db.query(
      'class_schedules',
      where: 'firestoreId = ?',
      whereArgs: [classSchedule.firestoreId],
    );
    final map = classSchedule.toMap()
      ..['firestoreId'] = classSchedule.firestoreId;
    if (existing.isEmpty) {
      await db.insert('class_schedules', map);
    } else {
      await db.update(
        'class_schedules',
        map,
        where: 'firestoreId = ?',
        whereArgs: [classSchedule.firestoreId],
      );
    }
  }

  /// Delete a class by its firestoreId (used during sync)
  Future<void> deleteByFirestoreId(String firestoreId) async {
    final db = await database;
    await db.delete(
      'class_schedules',
      where: 'firestoreId = ?',
      whereArgs: [firestoreId],
    );
  }

  Future<int> deleteClass(String id) async {
    final db = await database;
    return await db.delete(
      'class_schedules',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  Future<void> deleteAllClasses() async {
    final db = await database;
    await db.delete('class_schedules');
  }

  // ============ UI Preferences Methods ============

  /// Save column widths for each day (0-6 for Sunday-Saturday)
  Future<void> saveColumnWidths(List<double> widths) async {
    final db = await database;
    final json = jsonEncode(widths);

    await db.insert(
      'ui_preferences',
      {'key': 'column_widths', 'value': json},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load column widths, returns default [150.0] for all 7 days if not found
  Future<List<double>> loadColumnWidths() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'ui_preferences',
      where: 'key = ?',
      whereArgs: ['column_widths'],
    );

    if (result.isEmpty) {
      return List.filled(7, 150.0); // Default widths
    }

    try {
      final List<dynamic> decoded = jsonDecode(result.first['value']);
      return decoded.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      return List.filled(7, 150.0); // Fallback to defaults on error
    }
  }

  /// Save row heights for each hour (7-19 for 7 AM to 7 PM)
  /// Map key is the hour (7, 8, 9, etc.), value is the height
  Future<void> saveRowHeights(Map<int, double> heights) async {
    final db = await database;

    // Convert int keys to strings for JSON encoding
    final Map<String, double> stringKeyMap = {};
    heights.forEach((key, value) {
      stringKeyMap[key.toString()] = value;
    });

    final json = jsonEncode(stringKeyMap);

    await db.insert(
      'ui_preferences',
      {'key': 'row_heights', 'value': json},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load row heights for each hour, returns default 60.0 for all hours if not found
  Future<Map<int, double>> loadRowHeights() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'ui_preferences',
      where: 'key = ?',
      whereArgs: ['row_heights'],
    );

    // Default heights for hours 7-19 (7 AM to 7 PM)
    final defaultHeights = <int, double>{};
    for (int hour = 7; hour < 20; hour++) {
      defaultHeights[hour] = 60.0;
    }

    if (result.isEmpty) {
      return defaultHeights;
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(result.first['value']);
      final Map<int, double> heights = {};

      decoded.forEach((key, value) {
        heights[int.parse(key)] = (value as num).toDouble();
      });

      // Fill in any missing hours with default
      for (int hour = 7; hour < 20; hour++) {
        heights.putIfAbsent(hour, () => 60.0);
      }

      return heights;
    } catch (e) {
      return defaultHeights; // Fallback to defaults on error
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}