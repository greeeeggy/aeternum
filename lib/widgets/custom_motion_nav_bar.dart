// lib/widgets/custom_motion_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui show lerpDouble;

class CustomMotionNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color barColor;

  const CustomMotionNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.barColor,
  });

  @override
  State<CustomMotionNavBar> createState() => _CustomMotionNavBarState();
}

class _CustomMotionNavBarState extends State<CustomMotionNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  late int _fromIndex;
  late int _toIndex;

  static const List<Color> _colors = [
    Color(0xFFF06292), // 0 Period
    Color(0xFF4FC3F7), // 1 Messages
    Color(0xFF66BB6A), // 2 Home
    Color(0xFFFFB74D), // 3 Features
    Color(0xFF9575CD), // 4 Game
  ];

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex;
    _toIndex = widget.currentIndex;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubicEmphasized,
    );

    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant CustomMotionNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      setState(() {
        _fromIndex = oldWidget.currentIndex;
        _toIndex = widget.currentIndex;
      });
      _controller.forward(from: 0.0);
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _lerpColor() {
    return Color.lerp(
      _colors[_fromIndex],
      _colors[_toIndex],
      _animation.value,
    ) ??
        _colors[_toIndex];
  }

  @override
  Widget build(BuildContext context) {
    const double barHeight = 92.0;
    const double circleSize = 68.0;
    const double notchDepth = 62.0;
    const double notchWidthFactor = 0.42;

    return Container(
      height: barHeight,
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const itemCount = 5;
          final slotWidth = width / itemCount;
          final centerOfSlot = slotWidth / 2;

          return AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final t = _animation.value.clamp(0.0, 1.0);
              final startX = _fromIndex * slotWidth + centerOfSlot;
              final targetX = _toIndex * slotWidth + centerOfSlot;
              final animatedX = ui.lerpDouble(startX, targetX, t)!;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Wavy bar with smooth symmetric arc notch
                  ClipPath(
                    clipper: WavyNotchClipper(
                      centerX: animatedX,
                      barHeight: barHeight,
                      notchDepth: notchDepth,
                      notchWidthFactor: notchWidthFactor,
                    ),
                    child: Container(
                      color: widget.barColor,
                      foregroundDecoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.14),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Floating center circle
                  Positioned(
                    left: animatedX - circleSize / 2,
                    bottom: barHeight - circleSize / 2 + notchDepth - 80,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _lerpColor(),
                        boxShadow: [
                          BoxShadow(
                            color: _lerpColor().withOpacity(0.45),
                            blurRadius: 24,
                            spreadRadius: 6,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Icons row
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        5,
                            (i) => _NavItem(
                          index: i,
                          isSelected: _toIndex == i,
                          animation: _animation,
                          previousIndex: _fromIndex,
                          onTap: () {
                            if (i != _toIndex) {
                              widget.onTap(i);
                            } else if (i == 2) {
                              _controller.forward(from: 0.0);
                            }
                          },
                          badgeCount: i == 1 ? 3 : 0,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Improved smooth arc notch clipper
// ────────────────────────────────────────────────
class WavyNotchClipper extends CustomClipper<Path> {
  final double centerX;
  final double barHeight;
  final double notchDepth;
  final double notchWidthFactor;

  const WavyNotchClipper({
    required this.centerX,
    required this.barHeight,
    this.notchDepth = 34.0,
    this.notchWidthFactor = 0.36,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;

    path.moveTo(0, 0);

    final halfNotchWidth = width * notchWidthFactor / 2;
    final notchLeft = centerX - halfNotchWidth;
    final notchRight = centerX + halfNotchWidth;

    path.lineTo(notchLeft, 0);

    // Symmetric smooth arc using two cubic segments
    final controlOffset = halfNotchWidth * 0.62;

    path.cubicTo(
      notchLeft + controlOffset, 0,                    // control 1 left
      centerX - controlOffset, notchDepth * 0.92,      // control 2 left
      centerX, notchDepth,                             // bottom center
    );

    path.cubicTo(
      centerX + controlOffset, notchDepth * 0.92,      // control 1 right
      notchRight - controlOffset, 0,                   // control 2 right
      notchRight, 0,
    );

    path.lineTo(width, 0);

    // Bottom rectangle
    path.lineTo(width, barHeight);
    path.lineTo(0, barHeight);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant WavyNotchClipper oldClipper) {
    return oldClipper.centerX != centerX ||
        oldClipper.barHeight != barHeight ||
        oldClipper.notchDepth != notchDepth ||
        oldClipper.notchWidthFactor != notchWidthFactor;
  }
}

// ────────────────────────────────────────────────
// Nav Item (unchanged)
// ────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final int index;
  final bool isSelected;
  final Animation<double> animation;
  final int previousIndex;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.index,
    required this.isSelected,
    required this.animation,
    required this.previousIndex,
    required this.onTap,
    this.badgeCount = 0,
  });

  IconData _getIcon() {
    switch (index) {
      case 0:
        return Icons.calendar_today_rounded;
      case 1:
        return Icons.chat_bubble_outline_rounded;
      case 2:
        return Icons.home_rounded;
      case 3:
        return Icons.extension_rounded;
      case 4:
        return Icons.games_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double normalSize = 26.0;
    const double selectedSize = 32.0;
    const double liftDistance = 22.0;

    final double iconNormalSize = index == 2 ? 30.0 : normalSize;
    final double iconSelectedSize = index == 2 ? 34.0 : selectedSize;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                double t = 0.0;
                final bool wasSelected = previousIndex == index;
                final bool willBeSelected = isSelected;

                if (wasSelected && !willBeSelected) {
                  t = 1.0 - animation.value;
                } else if (!wasSelected && willBeSelected) {
                  t = animation.value;
                } else if (wasSelected && willBeSelected) {
                  t = 1.0;
                }

                final double yOffset = -liftDistance * t;
                final double scale = 1.0 + 0.24 * t;

                final double extraYOffset = index == 1 ? 2.0 : 0.0;
                final double extraXOffset = index == 3 ? 1.0 : 0.0;

                return Transform.translate(
                  offset: Offset(extraXOffset, yOffset + extraYOffset),
                  child: Transform.scale(
                    scale: scale,
                    child: Icon(
                      _getIcon(),
                      size: isSelected ? iconSelectedSize : iconNormalSize,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              },
            ),

            if (badgeCount > 0 && index == 1)
              Positioned(
                top: 6,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}