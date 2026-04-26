// lib/screens/root_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/onesignal_service.dart';

import '../widgets/custom_motion_nav_bar.dart';
import 'home_page.dart';
import 'chat_list_page.dart'; // ← REAL MessagingPage
import 'features_page.dart';
import 'game_page.dart';
import 'tracker/full_period_tracker_page.dart';
import 'tracker/boyfriend_period_viewer_page.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 2;
  String? _role;
  String? _pairId;
  List<Widget> _screens = [];
  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _role = 'unknown');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data()!;
      final role = data['role'] as String?;
      final pairId = data['pairId'] as String?;

      if (uid != null) {
        OneSignalService().login(uid);
      }

      if (pairId != null) {
        OneSignalService().addTag('pairId', pairId);
      }

      if (role == null || pairId == null) {
        setState(() => _role = 'unknown');
        return;
      }

      setState(() {
        _role = role;
        _pairId = pairId;
        _screens = [
          _role == 'boyfriend'
              ? const BoyfriendPeriodViewerPage()
              : const FullPeriodTrackerPage(),
          const ChatListPage(), // ← Direct with data
          HomePage(onShowTracker: () {
            if (mounted) setState(() => _selectedIndex = 0);
          }),
          const FeaturesPage(),
          const GamePage(),
        ];
      });
    } catch (e) {
      debugPrint("Error loading role: $e");
      setState(() => _role = 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null || _pairId == null || _screens.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.pink),
              SizedBox(height: 24),
              Text("Loading your experience..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomMotionNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        barColor: const Color(0xFFDEF3FD),
      ),
    );
  }
}