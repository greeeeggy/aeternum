// lib/database/message_database.dart
// ✅ UPDATED VERSION - Tombstone support for deleted messages

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:convert';

class MessageModel {
  final String id;
  final String senderUid;
  final String text;
  final int timestamp;
  final bool isRead;
  final bool isMe;
  final String threadId;
  final String threadType;
  final String aiMode;
  final String aiName;
  final Map<String, String> reactions;
  final bool isDeleted;
  final String? replyToId;

  MessageModel({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.timestamp,
    required this.isRead,
    required this.isMe,
    required this.threadId,
    required this.threadType,
    this.aiMode = 'none',
    this.aiName = '',
    this.reactions = const {},
    this.isDeleted = false,
    this.replyToId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUid': senderUid,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead ? 1 : 0,
      'isMe': isMe ? 1 : 0,
      'threadId': threadId,
      'threadType': threadType,
      'aiMode': aiMode,
      'aiName': aiName,
      'reactions': jsonEncode(reactions),
      'isDeleted': isDeleted ? 1 : 0,
      'replyToId': replyToId,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    Map<String, String> reactionsMap = {};
    if (map['reactions'] != null && map['reactions'] is String) {
      try {
        final decoded = jsonDecode(map['reactions'] as String);
        if (decoded is Map) {
          reactionsMap = Map<String, String>.from(decoded);
        }
      } catch (e) {
        // Invalid JSON, keep empty
      }
    }

    return MessageModel(
      id: map['id'] as String,
      senderUid: map['senderUid'] as String,
      text: map['text'] as String,
      timestamp: map['timestamp'] as int,
      isRead: map['isRead'] == 1,
      isMe: map['isMe'] == 1,
      threadId: map['threadId'] as String,
      threadType: map['threadType'] as String,
      aiMode: map['aiMode'] as String? ?? 'none',
      aiName: map['aiName'] as String? ?? '',
      reactions: reactionsMap,
      isDeleted: map['isDeleted'] == 1,
      replyToId: map['replyToId'] as String?,
    );
  }

  MessageModel copyWith({
    String? id,
    String? senderUid,
    String? text,
    int? timestamp,
    bool? isRead,
    bool? isMe,
    String? threadId,
    String? threadType,
    String? aiMode,
    String? aiName,
    Map<String, String>? reactions,
    bool? isDeleted,
    String? replyToId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderUid: senderUid ?? this.senderUid,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isMe: isMe ?? this.isMe,
      threadId: threadId ?? this.threadId,
      threadType: threadType ?? this.threadType,
      aiMode: aiMode ?? this.aiMode,
      aiName: aiName ?? this.aiName,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToId: replyToId ?? this.replyToId,
    );
  }
}

class LocalThread {
  final String threadId;
  final String title;
  final String nickname;
  final int lastMessageTime;
  final String aiMode;
  final String aiName;

  LocalThread({
    required this.threadId,
    required this.title,
    this.nickname = '',
    required this.lastMessageTime,
    this.aiMode = 'none',
    this.aiName = '',
  });

  Map<String, dynamic> toMap() => {
    'threadId': threadId,
    'title': title,
    'nickname': nickname,
    'lastMessageTime': lastMessageTime,
    'aiMode': aiMode,
    'aiName': aiName,
  };

  factory LocalThread.fromMap(Map<String, dynamic> map) => LocalThread(
    threadId: map['threadId'] as String,
    title: map['title'] as String,
    nickname: map['nickname'] as String? ?? '',
    lastMessageTime: map['lastMessageTime'] as int,
    aiMode: map['aiMode'] as String? ?? 'none',
    aiName: map['aiName'] as String? ?? '',
  );
}

class MessageDatabase {
  static final MessageDatabase _instance = MessageDatabase._internal();
  factory MessageDatabase() => _instance;
  MessageDatabase._internal();

  static Database? _database;

  final Map<String, StreamController<List<MessageModel>>> _messageControllers = {};

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'messages.db');

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    await deleteDatabase(path);
    print('🗑️ Database deleted');

    _database = await _initDB();
    print('✅ Database recreated with latest schema');
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'messages.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        print('🆕 Creating new database v$version');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            senderUid TEXT,
            text TEXT,
            timestamp INTEGER,
            isRead INTEGER,
            isMe INTEGER,
            threadId TEXT,
            threadType TEXT,
            aiMode TEXT,
            aiName TEXT,
            reactions TEXT DEFAULT '{}',
            isDeleted INTEGER DEFAULT 0,
            replyToId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE local_threads (
            threadId TEXT PRIMARY KEY,
            title TEXT,
            nickname TEXT,
            lastMessageTime INTEGER,
            aiMode TEXT,
            aiName TEXT
          )
        ''');
        print('✅ Database created successfully');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('🔄 Upgrading database from v$oldVersion to v$newVersion');

        if (oldVersion < 2) {
          print('📊 Applying v2 migrations...');
          if (!(await _columnExists(db, 'messages', 'threadId'))) {
            await db.execute('ALTER TABLE messages ADD COLUMN threadId TEXT');
            print('✅ Added threadId column');
          }
          if (!(await _columnExists(db, 'messages', 'threadType'))) {
            await db.execute('ALTER TABLE messages ADD COLUMN threadType TEXT');
            print('✅ Added threadType column');
          }
          await db.execute('''
            CREATE TABLE IF NOT EXISTS local_threads (
              threadId TEXT PRIMARY KEY,
              title TEXT,
              nickname TEXT,
              lastMessageTime INTEGER,
              aiMode TEXT,
              aiName TEXT
            )
          ''');
          print('✅ Created local_threads table');
        }

        if (oldVersion < 3) {
          print('📊 Applying v3 migrations...');
          if (!(await _columnExists(db, 'local_threads', 'aiMode'))) {
            await db.execute('ALTER TABLE local_threads ADD COLUMN aiMode TEXT');
            print('✅ Added aiMode to local_threads');
          }
          if (!(await _columnExists(db, 'local_threads', 'aiName'))) {
            await db.execute('ALTER TABLE local_threads ADD COLUMN aiName TEXT');
            print('✅ Added aiName to local_threads');
          }
          if (!(await _columnExists(db, 'messages', 'aiMode'))) {
            await db.execute('ALTER TABLE messages ADD COLUMN aiMode TEXT DEFAULT "none"');
            print('✅ Added aiMode to messages');
          }
          if (!(await _columnExists(db, 'messages', 'aiName'))) {
            await db.execute('ALTER TABLE messages ADD COLUMN aiName TEXT DEFAULT ""');
            print('✅ Added aiName to messages');
          }
        }

        if (oldVersion < 4) {
          print('📊 Applying v4 migrations...');
          if (!(await _columnExists(db, 'local_threads', 'nickname'))) {
            await db.execute('ALTER TABLE local_threads ADD COLUMN nickname TEXT DEFAULT ""');
            print('✅ Added nickname to local_threads');
          }
        }

        if (oldVersion < 5) {
          print('📊 Applying v5 migrations (reactions, isDeleted, replyToId)...');

          if (!(await _columnExists(db, 'messages', 'reactions'))) {
            await db.execute('ALTER TABLE messages ADD COLUMN reactions TEXT DEFAULT "{}"');
            print('✅ Added reactions column');
          }

          if (!(await _columnExists(db, 'messages', 'isDeleted'))) {
            await db.execute('ALTER TABLE messages ADD COLUMN isDeleted INTEGER DEFAULT 0');
            print('✅ Added isDeleted column');
          }

          if (!(await _columnExists(db, 'messages', 'replyToId'))) {
            await db.execute('ALTER TABLE messages ADD COLUMN replyToId TEXT');
            print('✅ Added replyToId column');
          }
        }

        print('✅ Database upgrade completed to v$newVersion');
      },
      onOpen: (db) async {
        print('🔍 Verifying database schema...');
        final hasReactions = await _columnExists(db, 'messages', 'reactions');
        final hasIsDeleted = await _columnExists(db, 'messages', 'isDeleted');
        final hasReplyToId = await _columnExists(db, 'messages', 'replyToId');

        if (!hasReactions || !hasIsDeleted || !hasReplyToId) {
          print('⚠️ Missing columns detected! Schema verification failed.');
          print('   reactions: $hasReactions, isDeleted: $hasIsDeleted, replyToId: $hasReplyToId');
          print('   Consider calling resetDatabase() to fix the schema.');
        } else {
          print('✅ Schema verification passed');
        }
      },
    );
  }

  Future<bool> _columnExists(Database db, String tableName, String columnName) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');
      for (var row in result) {
        if (row['name'] == columnName) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error checking column $columnName: $e');
      return false;
    }
  }

  StreamController<List<MessageModel>> _getController(String threadId) {
    if (!_messageControllers.containsKey(threadId)) {
      _messageControllers[threadId] = StreamController<List<MessageModel>>.broadcast();
      getMessagesByThreadId(threadId).then((messages) {
        if (!_messageControllers[threadId]!.isClosed) {
          _messageControllers[threadId]!.add(messages);
        }
      });
    }
    return _messageControllers[threadId]!;
  }

  Stream<List<MessageModel>> watchMessagesByThreadId(String threadId) {
    return _getController(threadId).stream;
  }

  Future<void> insertMessage(MessageModel message, String threadId, String threadType) async {
    final db = await database;
    await db.insert(
      'messages',
      {
        ...message.toMap(),
        'threadId': threadId,
        'threadType': threadType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (threadType == 'local') {
      final existingThreads = await db.query(
        'local_threads',
        where: 'threadId = ?',
        whereArgs: [threadId],
        limit: 1,
      );

      if (existingThreads.isEmpty) {
        await db.insert(
          'local_threads',
          {
            'threadId': threadId,
            'title': message.text.length > 20
                ? '${message.text.substring(0, 20)}...'
                : message.text,
            'nickname': '',
            'lastMessageTime': message.timestamp,
            'aiMode': message.aiMode,
            'aiName': message.aiName,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await db.update(
          'local_threads',
          {'lastMessageTime': message.timestamp},
          where: 'threadId = ?',
          whereArgs: [threadId],
        );
      }
    }

    if (_messageControllers.containsKey(threadId)) {
      final updatedMessages = await getMessagesByThreadId(threadId);
      if (!_messageControllers[threadId]!.isClosed) {
        _messageControllers[threadId]!.add(updatedMessages);
      }
    }
  }

  Future<void> updateMessage(MessageModel message) async {
    final db = await database;

    print('📝 Updating message ${message.id} in database...');

    final result = await db.update(
      'messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );

    print('📝 Updated $result row(s) for message ${message.id}');

    final threadId = message.threadId;

    final updatedMessages = await getMessagesByThreadId(threadId);
    print('📝 Fetched ${updatedMessages.length} messages for thread $threadId');

    if (_messageControllers.containsKey(threadId)) {
      if (!_messageControllers[threadId]!.isClosed) {
        print('📝 Emitting ${updatedMessages.length} messages to stream');
        _messageControllers[threadId]!.add(updatedMessages);
      } else {
        print('⚠️ Stream controller is closed for thread $threadId');
      }
    } else {
      print('⚠️ No stream controller found for thread $threadId');
      _getController(threadId).add(updatedMessages);
    }
  }

  Future<List<MessageModel>> getMessagesByThreadId(String threadId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((e) => MessageModel.fromMap(e)).toList();
  }

  Future<void> replaceMessagesForThread(String threadId, List<MessageModel> messages) async {
    final db = await database;

    print('🔄 Replacing messages for thread $threadId with ${messages.length} messages');

    await db.transaction((txn) async {
      final deleteCount = await txn.delete('messages', where: 'threadId = ?', whereArgs: [threadId]);
      print('🗑️ Deleted $deleteCount old messages');

      for (final msg in messages) {
        await txn.insert(
          'messages',
          {
            ...msg.toMap(),
            'threadId': threadId,
            'threadType': msg.threadType,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      print('✅ Inserted ${messages.length} new messages');
    });

    if (_messageControllers.containsKey(threadId)) {
      if (!_messageControllers[threadId]!.isClosed) {
        print('📤 Emitting updated messages to stream');
        _messageControllers[threadId]!.add(messages);
      }
    }
  }

  Future<void> debugPrintMessage(String messageId) async {
    final db = await database;
    final maps = await db.query('messages', where: 'id = ?', whereArgs: [messageId]);

    if (maps.isEmpty) {
      print('❌ Message $messageId not found in database');
    } else {
      final msg = MessageModel.fromMap(maps.first);
      print('🔍 Message $messageId state:');
      print('   text: ${msg.text}');
      print('   isDeleted: ${msg.isDeleted}');
      print('   reactions: ${msg.reactions}');
      print('   timestamp: ${msg.timestamp}');
    }
  }

  Future<MessageModel?> getMessageById(String id) async {
    final db = await database;
    final maps = await db.query('messages', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? MessageModel.fromMap(maps.first) : null;
  }

  // ✅ This method is NO LONGER USED for tombstone deletion
  // Keeping for backward compatibility
  Future<void> deleteMessage(String messageId) async {
    final db = await database;

    print('🗑️ Deleting message: $messageId');

    final results = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (results.isNotEmpty) {
      final threadId = results.first['threadId'] as String;

      final deleteCount = await db.delete(
          'messages',
          where: 'id = ?',
          whereArgs: [messageId]
      );

      print('✅ Deleted $deleteCount message(s) from database');

      if (_messageControllers.containsKey(threadId)) {
        final updatedMessages = await getMessagesByThreadId(threadId);
        if (!_messageControllers[threadId]!.isClosed) {
          print('📤 Emitting ${updatedMessages.length} messages to stream');
          _messageControllers[threadId]!.add(updatedMessages);
        } else {
          print('⚠️ Stream controller is closed');
        }
      } else {
        print('⚠️ No stream controller for thread $threadId');
      }
    } else {
      print('❌ Message $messageId not found in database');
    }
  }

  Future<void> saveLocalThread(LocalThread thread) async {
    final db = await database;
    await db.insert(
      'local_threads',
      thread.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocalThread>> getLocalThreads() async {
    final db = await database;
    final maps = await db.query('local_threads', orderBy: 'lastMessageTime DESC');
    return maps.map((e) => LocalThread.fromMap(e)).toList();
  }

  Future<void> deleteLocalThread(String threadId) async {
    final db = await database;
    await db.delete('messages', where: 'threadId = ?', whereArgs: [threadId]);
    await db.delete('local_threads', where: 'threadId = ?', whereArgs: [threadId]);
  }

  void disposeThreadStream(String threadId) {
    if (_messageControllers.containsKey(threadId)) {
      _messageControllers[threadId]!.close();
      _messageControllers.remove(threadId);
    }
  }

  void disposeAllStreams() {
    for (var controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
  }
}