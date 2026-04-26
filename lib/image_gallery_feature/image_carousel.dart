import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:overlapped_carousel/overlapped_carousel.dart';
import 'fullscreen_image_viewer.dart';

class ImageCarousel extends StatefulWidget {
  final List<String> imagePaths;

  const ImageCarousel({super.key, required this.imagePaths});

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late int _currentIndex;

  final int _repeatCount = 100; // how many times to repeat list for infinite illusion

  @override
  void initState() {
    super.initState();
    // start somewhere in the middle so user can scroll left/right seamlessly
    _currentIndex = _repeatCount ~/ 2 * widget.imagePaths.length;
  }

  void _onCarouselClicked(int index) {
    final int actualImageIndex = index % widget.imagePaths.length;
    final String imagePath = widget.imagePaths[actualImageIndex];
    final String heroTag = 'image_${imagePath}_$index';

    setState(() {
      _currentIndex = index;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imagePath: imagePath,
          heroTag: heroTag,
        ),
      ),
    );
  }

  List<Widget> _buildInfiniteImageList() {
    List<Widget> widgets = [];
    int globalIndex = 0;

    for (int i = 0; i < _repeatCount; i++) {
      for (String imagePath in widget.imagePaths) {
        widgets.add(_buildImageWidget(imagePath, globalIndex));
        globalIndex++;
      }
    }

    return widgets;
  }

  Widget _buildImageWidget(String imagePath, int index) {
    return GestureDetector(
      onTap: () => _onCarouselClicked(index),
      child: Hero(
        tag: 'image_${imagePath}_$index',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.length < 3) {
      return Center(
        child: Text(
          'At least 3 images required',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Center(
      child: SizedBox(
        height: min(screenWidth / 1.5 * (4 / 3), screenHeight * 0.6),
        child: OverlappedCarousel(
          widgets: _buildInfiniteImageList(),
          currentIndex: _currentIndex,
          onClicked: _onCarouselClicked,
          autoScroll: true, // Enable autoscroll
          autoScrollDuration: const Duration(seconds: 4), // Custom duration
          scrollAnimationDuration: const Duration(milliseconds: 800),
        ),
      ),
    );
  }
}