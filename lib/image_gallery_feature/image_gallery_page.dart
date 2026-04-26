import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'image_carousel.dart';
import 'image_storage_service.dart';
import 'image_gallery_database_helper.dart';
import 'gallery_creation_dialog.dart';

class GalleryWithImages {
  final Gallery gallery;
  final List<String> imagePaths;

  GalleryWithImages({
    required this.gallery,
    required this.imagePaths,
  });
}

class ImageGalleryPage extends StatefulWidget {
  const ImageGalleryPage({super.key});

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  final List<GalleryWithImages> _galleries = [];
  final ImagePicker _picker = ImagePicker();
  final ImageStorageService _storageService = ImageStorageService.instance;
  final ImageGalleryDatabaseHelper _dbHelper = ImageGalleryDatabaseHelper.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGalleries();
  }

  Future<void> _loadGalleries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final galleries = await _dbHelper.getAllGalleries();
      final galleriesWithImages = <GalleryWithImages>[];

      for (var gallery in galleries) {
        final imagePaths = await _storageService.loadImagesForGallery(gallery.id!);
        galleriesWithImages.add(GalleryWithImages(
          gallery: gallery,
          imagePaths: imagePaths,
        ));
      }

      setState(() {
        _galleries.clear();
        _galleries.addAll(galleriesWithImages);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading galleries: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateGalleryName(int index, String newName) {
    setState(() {
      _galleries[index] = GalleryWithImages(
        gallery: _galleries[index].gallery.copyWith(name: newName),
        imagePaths: _galleries[index].imagePaths,
      );
    });
  }

  void _addImagesToGalleryLocally(int index, List<String> newPaths) {
    setState(() {
      final updatedPaths = List<String>.from(_galleries[index].imagePaths)..addAll(newPaths);
      _galleries[index] = GalleryWithImages(
        gallery: _galleries[index].gallery,
        imagePaths: updatedPaths,
      );
    });
  }

  void _addNewGalleryLocally(Gallery gallery, List<String> imagePaths) {
    setState(() {
      _galleries.add(GalleryWithImages(
        gallery: gallery,
        imagePaths: imagePaths,
      ));
    });
  }

  void _reorderGalleries(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _galleries.removeAt(oldIndex);
      _galleries.insert(newIndex, item);
    });

    // Update order in database
    _updateGalleryOrderInDatabase();
  }

  Future<void> _updateGalleryOrderInDatabase() async {
    try {
      final galleries = _galleries.map((g) => g.gallery).toList();
      await _dbHelper.updateGalleryOrder(galleries);
    } catch (e) {
      debugPrint('Error updating gallery order: $e');
    }
  }

  Future<void> _createNewGallery() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const GalleryCreationDialog(),
    );

    if (result != null && mounted) {
      final String name = result['name'];
      final String designType = result['designType'];
      final int minImages = result['minImages'];

      // Pick images
      await _pickImagesForNewGallery(name, designType, minImages);
    }
  }

  Future<void> _pickImagesForNewGallery(
      String name,
      String designType,
      int minImages,
      ) async {
    final List<XFile> images = await _picker.pickMultiImage();

    if (images.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No images selected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (images.length < minImages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least $minImages images for this gallery design'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get next order index (new galleries go at the bottom)
      final maxOrderIndex = await _dbHelper.getMaxGalleryOrderIndex();
      final nextOrderIndex = maxOrderIndex + 1;

      // Create gallery in database
      final gallery = Gallery(
        name: name,
        designType: designType,
        orderIndex: nextOrderIndex,
        createdAt: DateTime.now(),
      );
      final galleryId = await _dbHelper.insertGallery(gallery);

      // Get temporary paths
      final tempPaths = images.map((img) => img.path).toList();

      // Save images to storage and database
      final savedPaths = await _storageService.saveImagesToGallery(tempPaths, galleryId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gallery "$name" created with ${savedPaths.length} images'),
            backgroundColor: Colors.green[700],
          ),
        );
      }

      // Add gallery locally without full reload
      final createdGallery = gallery.copyWith(id: galleryId);
      _addNewGalleryLocally(createdGallery, savedPaths);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error creating gallery: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating gallery: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _addImagesToGallery(int galleryIndex) async {
    final galleryWithImages = _galleries[galleryIndex];
    final gallery = galleryWithImages.gallery;

    final List<XFile> images = await _picker.pickMultiImage();

    if (images.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get temporary paths
      final tempPaths = images.map((img) => img.path).toList();

      // Save images to storage and database
      final savedPaths = await _storageService.saveImagesToGallery(
        tempPaths,
        gallery.id!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${savedPaths.length} images to "${gallery.name}"'),
            backgroundColor: Colors.green[700],
          ),
        );
      }

      // Update only this gallery locally without full reload
      _addImagesToGalleryLocally(galleryIndex, savedPaths);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error adding images: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding images: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _renameGallery(int galleryIndex) async {
    final galleryWithImages = _galleries[galleryIndex];
    final gallery = galleryWithImages.gallery;
    final TextEditingController controller = TextEditingController(text: gallery.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Rename Gallery',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    // Don't dispose the controller here - let it be garbage collected
    // Disposing it immediately causes an assertion error because the dialog
    // is still using it during the close animation

    if (newName != null && newName != gallery.name) {
      try {
        await _dbHelper.updateGalleryName(gallery.id!, newName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gallery renamed to "$newName"'),
              backgroundColor: Colors.green[700],
            ),
          );
        }

        // Update only this gallery locally without full reload
        _updateGalleryName(galleryIndex, newName);
      } catch (e) {
        debugPrint('Error renaming gallery: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error renaming gallery: $e'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  int _getMinImagesForDesign(String designType) {
    switch (designType) {
      case 'carousel':
        return 3;
      case 'grid':
        return 1;
      default:
        return 1;
    }
  }

  Widget _buildGalleryWidget(GalleryWithImages galleryWithImages, int index) {
    final gallery = galleryWithImages.gallery;
    final imagePaths = galleryWithImages.imagePaths;
    final minImages = _getMinImagesForDesign(gallery.designType);

    Widget content;

    if (imagePaths.isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 60,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              'No images yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    } else if (imagePaths.length < minImages) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 60,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              'Add ${minImages - imagePaths.length} more image${minImages - imagePaths.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Minimum $minImages images required',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    } else {
      // Show gallery based on design type
      switch (gallery.designType) {
        case 'carousel':
          content = ImageCarousel(imagePaths: imagePaths);
          break;
      // Add more cases for other designs in the future
        default:
          content = Center(
            child: Text(
              'Unknown gallery type',
              style: TextStyle(color: Colors.grey[400]),
            ),
          );
      }
    }

    return Container(
      key: ValueKey(gallery.id), // Add key for reordering
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with gallery name and menu button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _getIconForDesign(gallery.designType),
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gallery.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'add') {
                      _addImagesToGallery(index);
                    } else if (value == 'rename') {
                      _renameGallery(index);
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  color: Colors.grey[850],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'add',
                      child: Row(
                        children: [
                          Icon(Icons.add_photo_alternate, color: Colors.grey[400]),
                          const SizedBox(width: 12),
                          const Text(
                            'Add Images',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.grey[400]),
                          const SizedBox(width: 12),
                          const Text(
                            'Rename Gallery',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Gallery content
          SizedBox(
            height: 400,
            child: content,
          ),
        ],
      ),
    );
  }

  IconData _getIconForDesign(String designType) {
    switch (designType) {
      case 'carousel':
        return Icons.view_carousel;
      case 'grid':
        return Icons.grid_view;
      default:
        return Icons.photo_library;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Image Gallery', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Colors.grey[400],
        ),
      )
          : _galleries.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No galleries yet',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first gallery',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : ReorderableListView.builder(
        itemCount: _galleries.length,
        padding: const EdgeInsets.symmetric(vertical: 16),
        onReorder: _reorderGalleries,
        itemBuilder: (context, index) {
          return _buildGalleryWidget(_galleries[index], index);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewGallery,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add),
        tooltip: 'Create New Gallery',
      ),
    );
  }
}