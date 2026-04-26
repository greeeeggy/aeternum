import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

class UpdateRequiredScreen extends StatefulWidget {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateRequiredScreen({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  OtaEvent? _currentEvent;
  bool _isDownloading = false;
  String _errorMessage = '';

  void _startUpdate() {
    setState(() {
      _isDownloading = true;
      _errorMessage = '';
    });

    try {
      OtaUpdate().execute(widget.downloadUrl).listen(
        (OtaEvent event) {
          if (mounted) {
            setState(() {
              _currentEvent = event;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _errorMessage = 'Update failed: $e';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to execute update: $e';
        });
      }
    }
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
                    // Illustration or Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.pink.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.pink,
                        size: 64,
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
                      'An update is required to continue using Aeternum.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Version Bubble
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label_important_outline, size: 18, color: Colors.pink),
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
                          border: Border.all(color: Colors.pink.withOpacity(0.05)),
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
                    
                    if (_isDownloading) ...[
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _currentEvent?.value != null 
                                  ? double.tryParse(_currentEvent!.value!)! / 100 
                                  : 0,
                              minHeight: 12,
                              backgroundColor: Colors.pink.withOpacity(0.05),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
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
                      if (_errorMessage.isNotEmpty) ...[
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _startUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.pink.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Update Now',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
        return 'Downloading: ${_currentEvent!.value}%';
      case OtaStatus.INSTALLING:
        return 'Ready to install';
      case OtaStatus.ALREADY_RUNNING_ERROR:
        return 'Download already active';
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        return 'Storage permission required';
      default:
        return 'Please wait...';
    }
  }
}
