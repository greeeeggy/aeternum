
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

class UpdateRequiredScreen extends StatefulWidget {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final VoidCallback? onSkip;

  const UpdateRequiredScreen({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    this.onSkip,
  });

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen>
    with SingleTickerProviderStateMixin {
  OtaEvent? _currentEvent;
  bool _isDownloading = false;
  String _errorMessage = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startUpdate() {
    setState(() {
      _isDownloading = true;
      _errorMessage = '';
    });

    try {
      debugPrint('[OTA] Starting download from: ${widget.downloadUrl}');
      OtaUpdate().execute(widget.downloadUrl).listen(
        (OtaEvent event) {
          debugPrint('[OTA] Status: ${event.status}, Value: ${event.value}');
          if (mounted) {
            setState(() {
              _currentEvent = event;
            });

            // When the system installer is triggered, give it a moment
            if (event.status == OtaStatus.INSTALLING) {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  setState(() {
                    _isDownloading = false;
                  });
                }
              });
            }
          }
        },
        onError: (e) {
          debugPrint('[OTA] Error: $e');
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _errorMessage = 'Update failed: $e';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('[OTA] Execute error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to start update: $e';
        });
      }
    }
  }

  double _getProgress() {
    if (_currentEvent?.value == null) return 0;
    final parsed = double.tryParse(_currentEvent!.value!);
    if (parsed == null) return 0;
    return (parsed / 100).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFEBF2),
                  Color(0xFFFFF8F9),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.pink.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.pink,
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'New Version Ready!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'An update is available for Aeternum.\nUpdate now to get the latest features.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Version Bubble
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label_important_outline,
                              size: 18, color: Colors.pink),
                          const SizedBox(width: 8),
                          Text(
                            'Version ${widget.version}',
                            style: const TextStyle(
                              color: Colors.pink,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Release Notes
                    if (widget.releaseNotes.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "WHAT'S NEW",
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 200),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.pink.withValues(alpha: 0.05)),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            widget.releaseNotes,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],

                    // Download progress or buttons
                    if (_isDownloading) ...[
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _getProgress(),
                              minHeight: 12,
                              backgroundColor: Colors.pink.withValues(alpha: 0.05),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Colors.pink),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getStatusMessage(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Error message
                      if (_errorMessage.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade400, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Update Now button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _startUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.pink.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            _errorMessage.isNotEmpty
                                ? 'Retry Update'
                                : 'Update Now',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Skip button (only if callback provided)
                      if (widget.onSkip != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: widget.onSkip,
                          child: Text(
                            'Skip for now',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    if (_currentEvent == null) return 'Starting download...';
    switch (_currentEvent!.status) {
      case OtaStatus.DOWNLOADING:
        return 'Downloading: ${_currentEvent!.value ?? 0}%';
      case OtaStatus.INSTALLING:
        return 'Opening installer...';
      case OtaStatus.ALREADY_RUNNING_ERROR:
        return 'Download already active';
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        return 'Storage permission required';
      case OtaStatus.INTERNAL_ERROR:
        return 'Internal error occurred';
      default:
        return 'Please wait...';
    }
  }
}
