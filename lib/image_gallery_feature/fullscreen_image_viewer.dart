import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

class FullscreenImageViewer extends StatefulWidget {
  final String imagePath;
  final String heroTag;

  const FullscreenImageViewer({
    super.key,
    required this.imagePath,
    required this.heroTag,
  });

  @override
  State<FullscreenImageViewer> createState() =>
      _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  double _dragOffset = 0.0;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 150 ||
        details.primaryVelocity!.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 🔹 Blurred background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withOpacity(0.7),
            ),
          ),

          // 🔹 Drag-to-dismiss layer
          GestureDetector(
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    padding.top + 24,
                    24,
                    padding.bottom + 24,
                  ),
                  child: Hero(
                    tag: widget.heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🔹 Close button
          Positioned(
            top: padding.top + 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}