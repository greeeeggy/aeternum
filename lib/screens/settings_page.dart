// lib/screens/settings_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart'; // Helpful for readable date formatting
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'onboarding_page.dart';
import 'set_special_dates_page.dart';
import 'app_database.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // UI Design Constants (UNCHANGED)
  final Color _bgColor = const Color(0xFFF8F9FB);
  final Color _accentPink = const Color(0xFFFF85A1);
  final Color _lavenderChip = const Color(0xFFF3E5F5);

  String? _pairId;
  String? _monthsaryDateStr;
  String? _anniversaryDateStr;
  List<String> _nicknames = [];
  String? _appPhotoBase64; // App-specific profile photo, stored in Firestore

  bool _loading = true;
  bool _photoUploading = false;
  bool _cancelLoading = false; // ← ONLY NEW LOGIC FIELD

  @override
  void initState() {
    super.initState();
    _loadAndCacheData();
  }

  @override
  void dispose() {
    _cancelLoading = true; // ← CLEANUP
    super.dispose();
  }

  // --- LOGIC: Enhanced with cancel safety (UI unchanged) ---
  Future<void> _loadAndCacheData() async {
    _cancelLoading = false; // Reset for fresh load

    final user = _auth.currentUser;
    if (user == null) {
      return; // ← REMOVED _navigateToLogin() — AuthWrapper handles UI
    }

    try {
      if (_cancelLoading) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (_cancelLoading) return;

      if (!userDoc.exists) {
        return;
      }

      final userData = userDoc.data()!;
      final pairId = userData['pairId'] as String?;
      final nicknames = List<String>.from(userData['nicknames'] ?? []);
      final appPhotoBase64 = userData['appPhotoBase64'] as String?;

      if (pairId == null) {
        if (!_cancelLoading && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No pair found. Please re-onboard.")),
          );
        }
        return;
      }

      final coupleDoc = await _firestore.collection('couples').doc(pairId).get();
      if (_cancelLoading) return;

      String? monthsaryStr, anniversaryStr;

      if (coupleDoc.exists) {
        final coupleData = coupleDoc.data()!;
        final monthsaryTs = coupleData['monthsaryDate'] as Timestamp?;
        final anniversaryTs = coupleData['anniversaryDate'] as Timestamp?;

        monthsaryStr = monthsaryTs?.toDate().toIso8601String().split('T').first;
        anniversaryStr = anniversaryTs?.toDate().toIso8601String().split('T').first;
      }

      await AppDatabase().saveUserSettings(
        pairId: pairId,
        monthsaryDate: monthsaryStr,
        anniversaryDate: anniversaryStr,
        nicknames: nicknames,
      );

      if (!_cancelLoading && mounted) {
        setState(() {
          _pairId = pairId;
          _monthsaryDateStr = monthsaryStr;
          _anniversaryDateStr = anniversaryStr;
          _nicknames = nicknames;
          _appPhotoBase64 = appPhotoBase64;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Settings load error: $e");
      if (!_cancelLoading && mounted) {
        setState(() => _loading = false);
        Fluttertoast.showToast(msg: "Failed to load settings");
      }
    }
  }

  // ❌ REMOVED _navigateToLogin() — breaks AuthWrapper flow

  Future<void> _pickAndSavePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _photoUploading = true);

    try {
      // Compress to ~200x200, quality 70 — safely under Firestore 1MB doc limit
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 200,
        minHeight: 200,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) {
        Fluttertoast.showToast(msg: "Failed to process image");
        return;
      }

      final base64Str = base64Encode(compressed);
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'appPhotoBase64': base64Str,
      });

      if (mounted) {
        setState(() => _appPhotoBase64 = base64Str);
        Fluttertoast.showToast(msg: "Profile photo updated!");
      }
    } catch (e) {
      debugPrint("Photo save error: $e");
      Fluttertoast.showToast(msg: "Failed to save photo");
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _signOut() async {
    _cancelLoading = true; // ← Cancel any ongoing work

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Sign-out error: $e");
    }

    // Return to root (AuthWrapper will show LoginPage)
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _copyPairId() {
    if (_pairId != null) {
      Clipboard.setData(ClipboardData(text: _pairId!));
      HapticFeedback.mediumImpact(); // Subtle tactile feedback (KEPT)
      Fluttertoast.showToast(msg: "Pair ID copied!");
    }
  }

  Future<void> _refreshSettings() async {
    await _loadAndCacheData();
  }

  // --- UI COMPONENTS (100% UNCHANGED) ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroupedCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }

  String _readableDate(String? dateStr) {
    if (dateStr == null) return "Not set";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.pink))
          : RefreshIndicator(
        onRefresh: _refreshSettings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ACCOUNT SECTION
              _buildSectionHeader("Account"),
              _buildGroupedCard(
                child: Column(
                  children: [
                    // Profile picture + display name from Google account
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _photoUploading ? null : _pickAndSavePhoto,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 80,
                                  backgroundImage: _appPhotoBase64 != null
                                      ? MemoryImage(base64Decode(_appPhotoBase64!))
                                      : _auth.currentUser?.photoURL != null
                                          ? NetworkImage(_auth.currentUser!.photoURL!) as ImageProvider
                                          : null,
                                  child: (_appPhotoBase64 == null && _auth.currentUser?.photoURL == null)
                                      ? const Icon(Icons.person, size: 40)
                                      : _photoUploading
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.pinkAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_auth.currentUser?.displayName != null)
                            Text(
                              _auth.currentUser!.displayName!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          if (_auth.currentUser?.email != null)
                            Text(
                              _auth.currentUser!.email!,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // PAIR INFO SECTION
              if (_pairId != null) ...[
                _buildSectionHeader("Pair Information"),
                _buildGroupedCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Your Pair ID", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _pairId!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _copyPairId,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.pink.shade50,
                            foregroundColor: Colors.pink.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // SPECIAL DATES SECTION
              _buildSectionHeader("Special Dates"),
              _buildGroupedCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                      title: const Text("Monthsary"),
                      subtitle: Text(_readableDate(_monthsaryDateStr)),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.star_rounded, color: Colors.amber),
                      title: const Text("Anniversary"),
                      subtitle: Text(_readableDate(_anniversaryDateStr)),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SetSpecialDatesPage()),
                          );
                        },
                        child: const Text("Change Dates", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              // NICKNAMES SECTION
              _buildSectionHeader("Your Nicknames"),
              _buildGroupedCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_nicknames.isEmpty)
                        const Text("No nicknames yet.", style: TextStyle(color: Colors.grey)),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _nicknames.map((name) => Chip(
                          label: Text(name),
                          backgroundColor: _lavenderChip,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          labelStyle: TextStyle(color: Colors.purple.shade900, fontWeight: FontWeight.w500),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OnboardingPage(
                                initialNicknames: _nicknames,
                                isEditingMode: true,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.pink.shade100),
                        ),
                        label: const Text("Add/Edit Nicknames"),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // SIGN OUT
              _buildGroupedCard(
                child: ListTile(
                  title: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  onTap: _signOut,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}