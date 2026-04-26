import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('budget_planner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, // Version 6: added jointPairId, jointTargetId, jointFirestoreTxId to transactions
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN jointPairId TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN jointTargetId TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN jointFirestoreTxId TEXT');
      } catch (e) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN goalId INTEGER');
      } catch (e) {
        // Column might already exist
      }
    }

    if (oldVersion < 4) {
      // Run all v2 migrations first (safe to re-run due to try/catch)
      // Add name column to transactions if it doesn't exist
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN name TEXT');
      } catch (e) {
        // Column might already exist
      }

      // Add name column to recurring_transactions if it doesn't exist
      try {
        await db.execute('ALTER TABLE recurring_transactions ADD COLUMN name TEXT');
      } catch (e) {
        // Column might already exist
      }

      // Add endDate column to recurring_transactions if it doesn't exist
      try {
        await db.execute('ALTER TABLE recurring_transactions ADD COLUMN endDate TEXT');
      } catch (e) {
        // Column might already exist
      }

      // Add excludedDays column to recurring_transactions if it doesn't exist
      try {
        await db.execute('ALTER TABLE recurring_transactions ADD COLUMN excludedDays TEXT');
      } catch (e) {
        // Column might already exist
      }

      // Add recurringTransactionId column to transactions if it doesn't exist
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN recurringTransactionId INTEGER');
      } catch (e) {
        // Column might already exist
      }
    }

    if (oldVersion < 4) {
      // Insert default savings categories only if none exist (v3 may have already inserted them)
      final existingCount = await db.rawQuery(
        "SELECT COUNT(*) as c FROM categories WHERE type = ?",
        ['savings'],
      );
      if ((existingCount.first['c'] as int) == 0) {
        final now = DateTime.now().toIso8601String();
        final savingsCategories = [
          {'name': 'Travel Funds', 'icon': '✈️', 'color': 0xFFFFB300},
          {'name': 'Emergency Fund', 'icon': '🛡️', 'color': 0xFF42A5F5},
          {'name': 'General Savings', 'icon': '🐷', 'color': 0xFF66BB6A},
        ];
        for (var category in savingsCategories) {
          try {
            await db.insert('categories', {
              'name': category['name'],
              'type': 'savings',
              'icon': category['icon'],
              'color': category['color'],
              'isDefault': 1,
              'createdAt': now,
            });
          } catch (e) {
            // Skip on error
          }
        }
      }
    }

    if (oldVersion < 4) {
      // Add savings_goals table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS savings_goals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            targetAmount REAL NOT NULL,
            deadline TEXT NOT NULL,
            icon TEXT NOT NULL,
            color INTEGER NOT NULL,
            createdAt TEXT NOT NULL,
            completedAt TEXT
          )
        ''');
      } catch (e) {}

      // Add savings_goal_contributions table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS savings_goal_contributions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            goalId INTEGER NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (goalId) REFERENCES savings_goals (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        categoryId INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        recurringTransactionId INTEGER,
        goalId INTEGER,
        createdAt TEXT NOT NULL,
        jointPairId TEXT,
        jointTargetId TEXT,
        jointFirestoreTxId TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');

    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER,
        amount REAL NOT NULL,
        periodType TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Recurring transactions table
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        categoryId INTEGER NOT NULL,
        frequency TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        notes TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        lastGeneratedDate TEXT,
        excludedDays TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');

    // Savings goals table
    await db.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        deadline TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        completedAt TEXT
      )
    ''');

    // Savings goal contributions table
    await db.execute('''
      CREATE TABLE savings_goal_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goalId INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (goalId) REFERENCES savings_goals (id) ON DELETE CASCADE
      )
    ''');

    // Insert default categories
    await _insertDefaultCategories(db);
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Default expense categories
    final expenseCategories = [
      {'name': 'Food', 'icon': '🍔', 'color': 0xFFFF6B6B},
      {'name': 'Transport', 'icon': '🚗', 'color': 0xFF4ECDC4},
      {'name': 'Rent', 'icon': '🏠', 'color': 0xFF95E1D3},
      {'name': 'Utilities', 'icon': '💡', 'color': 0xFFFFA07A},
      {'name': 'Entertainment', 'icon': '🎮', 'color': 0xFFDDA15E},
      {'name': 'Shopping', 'icon': '🛍️', 'color': 0xFFBC6C25},
      {'name': 'Healthcare', 'icon': '⚕️', 'color': 0xFF06BEE1},
      {'name': 'Education', 'icon': '📚', 'color': 0xFF38A3A5},
    ];

    for (var category in expenseCategories) {
      await db.insert('categories', {
        'name': category['name'],
        'type': 'expense',
        'icon': category['icon'],
        'color': category['color'],
        'isDefault': 1,
        'createdAt': now,
      });
    }

    // Default income categories
    final incomeCategories = [
      {'name': 'Salary', 'icon': '💰', 'color': 0xFF4CAF50},
      {'name': 'Allowance', 'icon': '💵', 'color': 0xFF8BC34A},
      {'name': 'Business', 'icon': '💼', 'color': 0xFF009688},
      {'name': 'Investment', 'icon': '📈', 'color': 0xFF00BCD4},
    ];

    for (var category in incomeCategories) {
      await db.insert('categories', {
        'name': category['name'],
        'type': 'income',
        'icon': category['icon'],
        'color': category['color'],
        'isDefault': 1,
        'createdAt': now,
      });
    }

    // Default savings categories
    final savingsCategories = [
      {'name': 'Travel Funds', 'icon': '✈️', 'color': 0xFFFFB300},
      {'name': 'Emergency Fund', 'icon': '🛡️', 'color': 0xFF42A5F5},
      {'name': 'General Savings', 'icon': '🐷', 'color': 0xFF66BB6A},
    ];

    for (var category in savingsCategories) {
      await db.insert('categories', {
        'name': category['name'],
        'type': 'savings',
        'icon': category['icon'],
        'color': category['color'],
        'isDefault': 1,
        'createdAt': now,
      });
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}