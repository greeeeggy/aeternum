import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class GalleryImage {
  final int? id;
  final int galleryId;
  final String filePath;
  final int orderIndex;
  final DateTime createdAt;

  GalleryImage({
    this.id,
    required this.galleryId,
    required this.filePath,
    required this.orderIndex,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gallery_id': galleryId,
      'file_path': filePath,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GalleryImage.fromMap(Map<String, dynamic> map) {
    return GalleryImage(
      id: map['id'] as int,
      galleryId: map['gallery_id'] as int,
      filePath: map['file_path'] as String,
      orderIndex: map['order_index'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class Gallery {
  final int? id;
  final String name;
  final String designType; // 'carousel', 'grid', etc.
  final int orderIndex;
  final DateTime createdAt;

  Gallery({
    this.id,
    required this.name,
    required this.designType,
    required this.orderIndex,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'design_type': designType,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Gallery.fromMap(Map<String, dynamic> map) {
    return Gallery(
      id: map['id'] as int,
      name: map['name'] as String,
      designType: map['design_type'] as String,
      orderIndex: map['order_index'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Gallery copyWith({
    int? id,
    String? name,
    String? designType,
    int? orderIndex,
    DateTime? createdAt,
  }) {
    return Gallery(
      id: id ?? this.id,
      name: name ?? this.name,
      designType: designType ?? this.designType,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ImageGalleryDatabaseHelper {
  static final ImageGalleryDatabaseHelper instance = ImageGalleryDatabaseHelper._init();
  static Database? _database;

  ImageGalleryDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gallery_images.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create galleries table
    await db.execute('''
      CREATE TABLE galleries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        design_type TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create gallery_images table with foreign key to galleries
    await db.execute('''
      CREATE TABLE gallery_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gallery_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (gallery_id) REFERENCES galleries (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create new galleries table
      await db.execute('''
        CREATE TABLE galleries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          design_type TEXT NOT NULL,
          order_index INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      // Create new gallery_images table
      await db.execute('''
        CREATE TABLE gallery_images_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          gallery_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          order_index INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (gallery_id) REFERENCES galleries (id) ON DELETE CASCADE
        )
      ''');

      // Migrate existing data if any
      final existingImages = await db.query('gallery_images');
      if (existingImages.isNotEmpty) {
        // Create a default gallery for existing images
        final defaultGalleryId = await db.insert('galleries', {
          'name': 'My Gallery',
          'design_type': 'carousel',
          'order_index': 0,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Migrate images to new table with gallery_id
        for (var image in existingImages) {
          await db.insert('gallery_images_new', {
            'gallery_id': defaultGalleryId,
            'file_path': image['file_path'],
            'order_index': image['order_index'],
            'created_at': image['created_at'],
          });
        }
      }

      // Drop old table and rename new one
      await db.execute('DROP TABLE gallery_images');
      await db.execute('ALTER TABLE gallery_images_new RENAME TO gallery_images');
    }

    if (oldVersion < 3) {
      // Add order_index column if upgrading from version 2
      try {
        await db.execute('ALTER TABLE galleries ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0');

        // Set order_index based on created_at for existing galleries
        final galleries = await db.query('galleries', orderBy: 'created_at ASC');
        for (int i = 0; i < galleries.length; i++) {
          await db.update(
            'galleries',
            {'order_index': i},
            where: 'id = ?',
            whereArgs: [galleries[i]['id']],
          );
        }
      } catch (e) {
        // Column might already exist
        debugPrint('order_index column might already exist: $e');
      }
    }
  }

  // Gallery operations
  Future<int> insertGallery(Gallery gallery) async {
    final db = await database;
    return await db.insert('galleries', gallery.toMap());
  }

  Future<List<Gallery>> getAllGalleries() async {
    final db = await database;
    final result = await db.query(
      'galleries',
      orderBy: 'order_index ASC',
    );

    return result.map((map) => Gallery.fromMap(map)).toList();
  }

  Future<int> deleteGallery(int id) async {
    final db = await database;
    return await db.delete(
      'galleries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateGalleryName(int id, String newName) async {
    final db = await database;
    return await db.update(
      'galleries',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateGalleryOrder(List<Gallery> galleries) async {
    final db = await database;
    final batch = db.batch();

    for (int i = 0; i < galleries.length; i++) {
      batch.update(
        'galleries',
        {'order_index': i},
        where: 'id = ?',
        whereArgs: [galleries[i].id],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<int> getMaxGalleryOrderIndex() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(order_index) as max_order FROM galleries');
    final maxOrder = result.first['max_order'];
    return maxOrder != null ? (maxOrder as int) : -1;
  }

  // Image operations
  Future<int> insertImage(GalleryImage image) async {
    final db = await database;
    return await db.insert('gallery_images', image.toMap());
  }

  Future<List<GalleryImage>> getImagesForGallery(int galleryId) async {
    final db = await database;
    final result = await db.query(
      'gallery_images',
      where: 'gallery_id = ?',
      whereArgs: [galleryId],
      orderBy: 'order_index ASC',
    );

    return result.map((map) => GalleryImage.fromMap(map)).toList();
  }

  Future<List<GalleryImage>> getAllImages() async {
    final db = await database;
    final result = await db.query(
      'gallery_images',
      orderBy: 'order_index ASC',
    );

    return result.map((map) => GalleryImage.fromMap(map)).toList();
  }

  Future<int> deleteImage(int id) async {
    final db = await database;
    return await db.delete(
      'gallery_images',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllImages() async {
    final db = await database;
    await db.delete('gallery_images');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}