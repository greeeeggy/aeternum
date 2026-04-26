// lib/services/note_database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/shared_note.dart';

class NoteDatabase {
  static final NoteDatabase instance = NoteDatabase._init();
  static Database? _database;

  NoteDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shared_notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        docId TEXT,
        title TEXT,
        content TEXT,
        color INTEGER,
        isPinned INTEGER,
        createdAt INTEGER,
        updatedAt INTEGER,
        createdBy TEXT,
        isSynced INTEGER,
        isDeleted INTEGER
      )
    ''');
  }

  // CRUD Methods
  Future<SharedNote> create(SharedNote note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    return SharedNote.fromMap(note.toMap()..['id'] = id);
  }

  Future<List<SharedNote>> getAllUnDeleted() async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'isDeleted = ?',
      whereArgs: [0],
      orderBy: 'updatedAt DESC',
    );
    return List.generate(maps.length, (i) => SharedNote.fromMap(maps[i]));
  }

  Future<void> update(SharedNote note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // Soft-delete locally + mark for Firebase deletion
  Future<void> delete(int id) async {
    final db = await database;
    await db.update(
      'notes',
      {'isDeleted': 1, 'isSynced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get all notes that need syncing (created/updated/deleted)
  Future<List<SharedNote>> getUnsyncedNotes() async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) => SharedNote.fromMap(maps[i]));
  }

  Future<SharedNote?> getNoteByDocId(String docId) async {
    final db = await database;
    final maps = await db.query('notes', where: 'docId = ?', whereArgs: [docId]);
    return maps.isNotEmpty ? SharedNote.fromMap(maps.first) : null;
  }

  // Mark as synced
  Future<void> markAsSynced(int id, String docId) async {
    final db = await database;
    await db.update(
      'notes',
      {'isSynced': 1, 'docId': docId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // After successful Firebase delete, hard-delete locally by id
  Future<void> hardDelete(int id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // Hard-delete by Firestore docId (used when syncing deletions from Firebase)
  Future<int> hardDeleteByDocId(String docId) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'docId = ?',
      whereArgs: [docId],
    );
  }
}