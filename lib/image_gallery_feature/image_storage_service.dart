import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'image_gallery_database_helper.dart';

class ImageStorageService {
  static final ImageStorageService instance = ImageStorageService._init();
  final ImageGalleryDatabaseHelper _dbHelper = ImageGalleryDatabaseHelper.instance;

  ImageStorageService._init();

  Future<Directory> _getStorageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final storageDir = Directory('${appDir.path}/gallery_images');

    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }

    return storageDir;
  }

  Future<List<String>> saveImagesToGallery(List<String> tempPaths, int galleryId) async {
    final storageDir = await _getStorageDirectory();
    final savedPaths = <String>[];

    try {
      // Get current max order index for this gallery
      final existingImages = await _dbHelper.getImagesForGallery(galleryId);
      int orderIndex = existingImages.length;

      for (String tempPath in tempPaths) {
        final tempFile = File(tempPath);

        if (!await tempFile.exists()) {
          debugPrint('Temp file does not exist: $tempPath');
          continue;
        }

        // Generate unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = path.extension(tempPath);
        final fileName = 'img_${timestamp}_${orderIndex}$extension';
        final permanentPath = '${storageDir.path}/$fileName';

        // Copy to permanent storage
        await tempFile.copy(permanentPath);

        // Save to database with gallery_id
        final galleryImage = GalleryImage(
          galleryId: galleryId,
          filePath: permanentPath,
          orderIndex: orderIndex,
          createdAt: DateTime.now(),
        );

        await _dbHelper.insertImage(galleryImage);
        savedPaths.add(permanentPath);
        orderIndex++;
      }

      return savedPaths;
    } catch (e) {
      debugPrint('Error in saveImagesToGallery: $e');
      rethrow;
    }
  }

  // Legacy method for backward compatibility (if needed elsewhere)
  Future<List<String>> saveImagesToStorage(List<String> tempPaths) async {
    // This would need a default gallery or throw an error
    // For now, keeping it but it should be avoided
    throw UnimplementedError('Use saveImagesToGallery instead');
  }

  Future<List<String>> loadImagesForGallery(int galleryId) async {
    try {
      final images = await _dbHelper.getImagesForGallery(galleryId);

      // Filter out any images whose files no longer exist
      final validPaths = <String>[];
      for (var image in images) {
        if (await File(image.filePath).exists()) {
          validPaths.add(image.filePath);
        } else {
          // Clean up database entry for missing file
          if (image.id != null) {
            await _dbHelper.deleteImage(image.id!);
          }
        }
      }

      return validPaths;
    } catch (e) {
      debugPrint('Error loading images for gallery: $e');
      return [];
    }
  }

  Future<List<String>> loadAllImages() async {
    try {
      final images = await _dbHelper.getAllImages();

      final validPaths = <String>[];
      for (var image in images) {
        if (await File(image.filePath).exists()) {
          validPaths.add(image.filePath);
        } else {
          if (image.id != null) {
            await _dbHelper.deleteImage(image.id!);
          }
        }
      }

      return validPaths;
    } catch (e) {
      debugPrint('Error loading all images: $e');
      return [];
    }
  }

  Future<void> deleteImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Find and delete from database
      final images = await _dbHelper.getAllImages();
      final imageToDelete = images.firstWhere(
            (img) => img.filePath == filePath,
        orElse: () => throw Exception('Image not found in database'),
      );

      if (imageToDelete.id != null) {
        await _dbHelper.deleteImage(imageToDelete.id!);
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
      rethrow;
    }
  }

  Future<void> deleteAllImages() async {
    try {
      final storageDir = await _getStorageDirectory();

      if (await storageDir.exists()) {
        await storageDir.delete(recursive: true);
        await storageDir.create();
      }

      await _dbHelper.deleteAllImages();
    } catch (e) {
      debugPrint('Error deleting all images: $e');
      rethrow;
    }
  }
}