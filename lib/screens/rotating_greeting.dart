// lib/widgets/rotating_greeting.dart

import 'dart:async';
import 'package:flutter/material.dart';

class RotatingGreeting extends StatefulWidget {
  final List<String> nicknames;
  final bool isGirlfriend; // true = girlfriend mode (girly), false = boyfriend mode (manly)

  const RotatingGreeting({
    super.key,
    required this.nicknames,
    required this.isGirlfriend,
  });

  @override
  State<RotatingGreeting> createState() => _RotatingGreetingState();
}

class _RotatingGreetingState extends State<RotatingGreeting> with TickerProviderStateMixin {
  late int _currentIndex;
  String _displayedText = "";
  Timer? _rotationTimer;
  Timer? _typingTimer;

  late AnimationController _cursorController;
  late Animation<double> _cursorOpacity;

  late AnimationController _heartPulseController;
  late Animation<double> _heartScale;

  bool _showCursor = true;
  bool _isDeleting = false;
  bool _showPulsingHeart = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;

    // Cursor blink
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _cursorOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(_cursorController);

    // Heart pulse
    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _heartPulseController, curve: Curves.easeInOut));

    final initialName = widget.nicknames.isNotEmpty ? widget.nicknames[0] : "Love";
    _startTyping(initialName, isDeleting: false);

    _startRotation();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _typingTimer?.cancel();
    _cursorController.dispose();
    _heartPulseController.dispose();
    super.dispose();
  }

  void _startRotation() {
    if (widget.nicknames.length <= 1) return;

    _rotationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final nextIndex = (_currentIndex + 1) % widget.nicknames.length;
      setState(() => _currentIndex = nextIndex);
      _startDeleting();
    });
  }

  void _startDeleting() {
    _typingTimer?.cancel();
    setState(() {
      _isDeleting = true;
      _showCursor = true;
      _showPulsingHeart = false;
    });

    int charIndex = _displayedText.length;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex > 0) {
        setState(() => _displayedText = _displayedText.substring(0, charIndex - 1));
        charIndex--;
      } else {
        timer.cancel();
        final nextName = widget.nicknames[_currentIndex];
        _startTyping(nextName, isDeleting: false);
      }
    });
  }

  void _startTyping(String fullText, {required bool isDeleting}) {
    _typingTimer?.cancel();
    setState(() {
      _isDeleting = isDeleting;
      _showCursor = true;
      _showPulsingHeart = false;
    });

    if (isDeleting) return;

    int charIndex = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < fullText.length) {
        setState(() => _displayedText = fullText.substring(0, charIndex + 1));
        charIndex++;
      } else {
        timer.cancel();
        setState(() => _showCursor = false);
        _showPulsingHeart = true;
        _heartPulseController.repeat(reverse: true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _heartPulseController.stop();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Role-based theming ────────────────────────────────────────
    final isGf = widget.isGirlfriend;

    final primaryColor    = isGf ? const Color(0xFFEC4899) : const Color(0xFF0F766E);     // pink vs teal
    final gradientColors  = isGf
        ? [const Color(0xFFEC4899), const Color(0xFFF472B6), const Color(0xFFFFB3B9)]
        : [const Color(0xFF0F766E), const Color(0xFF115E5C), const Color(0xFF2DD4BF)];
    final cursorColor     = isGf ? Colors.pinkAccent : const Color(0xFF2DD4BF);
    final heartColor      = isGf ? const Color(0xFFEC4899) : const Color(0xFF0F766E);
    final pillBorderRadius = isGf ? 24.0 : 16.0; // softer rounding = girlier
    final shadowOpacity   = isGf ? 0.22 : 0.14;  // stronger shadow for girly

    final text = "Hello, $_displayedText";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(pillBorderRadius),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(shadowOpacity),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (_showCursor)
            FadeTransition(
              opacity: _cursorOpacity,
              child: Text(
                "│",
                style: TextStyle(
                  fontSize: 28,
                  color: cursorColor.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_showPulsingHeart)
            ScaleTransition(
              scale: _heartScale,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  "💗",
                  style: TextStyle(fontSize: 28, color: heartColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}