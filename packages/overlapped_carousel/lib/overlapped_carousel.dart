library overlapped_carousel;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'card.dart';

class OverlappedCarousel extends StatefulWidget {
  final List<Widget> widgets;
  final Function(int) onClicked;
  final int? currentIndex;
  final double obscure;
  final double skewAngle;

  // Autoscroll parameters
  final bool autoScroll;
  final Duration autoScrollDuration;
  final Duration scrollAnimationDuration;

  OverlappedCarousel({
    required this.widgets,
    required this.onClicked,
    this.currentIndex,
    this.obscure = 0,
    this.skewAngle = -0.25,
    this.autoScroll = false,
    this.autoScrollDuration = const Duration(seconds: 5),
    this.scrollAnimationDuration = const Duration(milliseconds: 800),
  });

  @override
  _OverlappedCarouselState createState() => _OverlappedCarouselState();
}

class _OverlappedCarouselState extends State<OverlappedCarousel>
    with SingleTickerProviderStateMixin {
  double currentIndex = 2;
  Timer? _autoScrollTimer;
  bool _isUserInteracting = false;
  late AnimationController _animationController;
  Animation<double>? _animation;
  double _animationStartIndex = 2;

  @override
  void initState() {
    super.initState();
    if (widget.currentIndex != null)
      currentIndex = widget.currentIndex!.toDouble();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.scrollAnimationDuration,
    );

    _animationController.addListener(() {
      if (_animation != null) {
        setState(() {
          currentIndex = _animation!.value;
        });
      }
    });

    if (widget.autoScroll) {
      _startAutoScroll();
    }
  }

  @override
  void didUpdateWidget(OverlappedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update currentIndex if it changed from parent
    if (widget.currentIndex != null &&
        widget.currentIndex != oldWidget.currentIndex) {
      _animateToIndex(widget.currentIndex!.toDouble());
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _animateToIndex(double targetIndex) {
    _animationStartIndex = currentIndex;
    _animation = Tween<double>(
      begin: _animationStartIndex,
      end: targetIndex,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward(from: 0);
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(widget.autoScrollDuration, (timer) {
      if (!_isUserInteracting && mounted) {
        double nextIndex = currentIndex.ceil().toDouble() + 1;

        // Only enforce bounds check
        if (nextIndex <= widget.widgets.length - 3) {
          _animateToIndex(nextIndex);
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  void _handlePanStart() {
    _isUserInteracting = true;
    _animationController.stop();
    if (widget.autoScroll) {
      _stopAutoScroll();
    }
  }

  void _handlePanEnd() {
    _isUserInteracting = false;
    if (widget.autoScroll) {
      _startAutoScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onPanStart: (details) {
              _handlePanStart();
            },
            onPanUpdate: (details) {
              setState(() {
                var indx = currentIndex - details.delta.dx * 0.02;
                if (indx >= 1 && indx <= widget.widgets.length - 3)
                  currentIndex = indx;
              });
            },
            onPanEnd: (details) {
              setState(() {
                currentIndex = currentIndex.ceil().toDouble();
              });
              _handlePanEnd();
            },
            child: OverlappedCarouselCardItems(
              cards: List.generate(
                widget.widgets.length,
                    (index) => CardModel(
                  id: index,
                  child: widget.widgets[index],
                ),
              ),
              centerIndex: currentIndex,
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
              onClicked: widget.onClicked,
              obscure: widget.obscure,
              skewAngle: widget.skewAngle,
            ),
          );
        },
      ),
    );
  }
}

class OverlappedCarouselCardItems extends StatelessWidget {
  final List<CardModel> cards;
  final Function(int) onClicked;
  final double centerIndex;
  final double maxHeight;
  final double maxWidth;
  final double obscure;
  final double skewAngle;

  OverlappedCarouselCardItems({
    required this.cards,
    required this.centerIndex,
    required this.maxHeight,
    required this.maxWidth,
    required this.onClicked,
    required this.obscure,
    required this.skewAngle,
  });

  double getCardPosition(int index) {
    final double center = maxWidth / 2;
    final double centerWidgetWidth = maxWidth / 4;
    final double basePosition = center - centerWidgetWidth / 2 - 12;
    final distance = centerIndex - index;

    final double nearWidgetWidth = centerWidgetWidth / 5 * 4;
    final double farWidgetWidth = centerWidgetWidth / 5 * 3;

    if (distance == 0) {
      return basePosition;
    } else if (distance.abs() > 0.0 && distance.abs() <= 1.0) {
      if (distance > 0) {
        return basePosition - nearWidgetWidth * distance.abs();
      } else {
        return basePosition + centerWidgetWidth * distance.abs();
      }
    } else if (distance.abs() >= 1.0 && distance.abs() <= 2.0) {
      if (distance > 0) {
        return (basePosition - nearWidgetWidth) -
            farWidgetWidth * (distance.abs() - 1);
      } else {
        return (basePosition + centerWidgetWidth + nearWidgetWidth) +
            farWidgetWidth * (distance.abs() - 2) -
            (nearWidgetWidth - farWidgetWidth) *
                ((distance - distance.floor()));
      }
    } else {
      if (distance > 0) {
        return (basePosition - nearWidgetWidth) -
            farWidgetWidth * (distance.abs() - 1);
      } else {
        return (basePosition + centerWidgetWidth + nearWidgetWidth) +
            farWidgetWidth * (distance.abs() - 2);
      }
    }
  }

  double getCardWidth(int index) {
    final double distance = (centerIndex - index).abs();
    final double centerWidgetWidth = maxWidth / 3.5;
    final double nearWidgetWidth = centerWidgetWidth / 5 * 4.5;
    final double farWidgetWidth = centerWidgetWidth / 5 * 3.5;

    if (distance >= 0.0 && distance < 1.0) {
      return centerWidgetWidth -
          (centerWidgetWidth - nearWidgetWidth) * (distance - distance.floor());
    } else if (distance >= 1.0 && distance < 2.0) {
      return nearWidgetWidth -
          (nearWidgetWidth - farWidgetWidth) * (distance - distance.floor());
    } else {
      return farWidgetWidth;
    }
  }

  Matrix4 getTransform(int index) {
    final distance = centerIndex - index;

    var transform = Matrix4.identity()
      ..setEntry(3, 2, 0.007)
      ..rotateY(skewAngle * distance)
      ..scale(1.25, 1.25, 1.25);
    if (index == centerIndex) transform..scale(1.05, 1.05, 1.05);
    return transform;
  }

  Widget _buildItem(CardModel item) {
    final int index = item.id;
    final width = getCardWidth(index);
    final height = maxHeight - 20 * (centerIndex - index).abs();
    final position = getCardPosition(index);
    final verticalPadding = width * 0.05 * (centerIndex - index).abs();

    return Positioned(
      left: position,
      child: Transform(
        transform: getTransform(index),
        alignment: FractionalOffset.center,
        child: Stack(
          children: [
            Container(
              width: width.toDouble(),
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
              height: height > 0 ? height : 0,
              child: item.child,
            ),
            Container(
              width: width.toDouble(),
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
              height: height > 0 ? height : 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: getFilter(obscure, index),
                  child: Container(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageFilter getFilter(double obscure, int index) {
    final distance = (centerIndex - index).abs();
    return ImageFilter.blur(
        sigmaX: 5.0 * obscure * distance, sigmaY: 5.0 * obscure * distance);
  }

  List<Widget> _sortedStackWidgets(List<CardModel> widgets) {
    for (int i = 0; i < widgets.length; i++) {
      if (widgets[i].id == centerIndex) {
        widgets[i].zIndex = widgets.length.toDouble();
      } else if (widgets[i].id < centerIndex) {
        widgets[i].zIndex = widgets[i].id.toDouble();
      } else {
        widgets[i].zIndex =
            widgets.length.toDouble() - widgets[i].id.toDouble();
      }
    }
    widgets.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return widgets.map((e) {
      double distance = (centerIndex - e.id).abs();
      if (distance >= 0 && distance <= 3)
        return _buildItem(e);
      else
        return Container();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: AlignmentDirectional.center,
        clipBehavior: Clip.none,
        children: _sortedStackWidgets(cards),
      ),
    );
  }
}