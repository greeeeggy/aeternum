import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'set_special_dates_page.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  final String? role;
  final String? pairId;
  final List<String>? initialNicknames; // ← ADDED
  final bool isEditingMode; // ← ADDED

  const OnboardingPage({
    super.key,
    this.role,
    this.pairId,
    this.initialNicknames, // ← ADDED
    this.isEditingMode = false, // ← ADDED (default: false = onboarding flow)
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late List<TextEditingController> _controllers; // ← changed to 'late'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // ← ADDED: Initialize with existing nicknames if provided
    if (widget.initialNicknames != null && widget.initialNicknames!.isNotEmpty) {
      _controllers = widget.initialNicknames!
          .map((name) => TextEditingController(text: name))
          .toList();
    } else {
      _controllers = [TextEditingController()];
    }
  }

  void _addNicknameField() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  Future<void> _saveNicknames() async {
    final nicknames = <String>[];
    for (final controller in _controllers) {
      final nick = controller.text.trim();
      if (nick.isNotEmpty) {
        nicknames.add(nick);
      }
    }
    if (nicknames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one special name 💗")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email?.isEmpty == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sign-in incomplete. Returning to login.")),
        );
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginPage()));
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      // Fetch role/pairId if not passed (rare; gate ensures role exists)
      String? role = widget.role;
      String? pairId = widget.pairId;
      if (role == null || pairId == null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final docData = doc.data();
        role ??= docData?['role'] as String?;
        pairId ??= docData?['pairId'] as String?;
      }
      if (role == null || pairId == null) {
        throw Exception('Missing role or pair—complete role setup first.');
      }

      final Map<String, dynamic> updates = {
        'nicknames': nicknames,
        'createdAt': FieldValue.serverTimestamp(),
        'email': user.email!,
        'role': role,  // Ensure set
        'pairId': pairId,  // Ensure set
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        updates,
        SetOptions(merge: true),
      );

      if (mounted) {
        // ← CHANGED: Navigate based on mode
        if (widget.isEditingMode) {
          Navigator.of(context).pop(); // Return to Settings
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const SetSpecialDatesPage()),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView( // ← WRAPPED HERE
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFE91E63), size: 80),
                const SizedBox(height: 20),
                const Text(
                  "What do you call her? 💕",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE91E63),
                  ),
                ),
                const SizedBox(height: 20),
                ..._controllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: index == 0 ? "First special name (e.g., Love)" : "Another one? (e.g., Babe)",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        suffixIcon: index > 0
                            ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              controller.dispose();
                              _controllers.removeAt(index);
                            });
                          },
                        )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
                TextButton.icon(
                  onPressed: _addNicknameField,
                  icon: const Icon(Icons.add, color: Color(0xFFE91E63)),
                  label: const Text("Add Another Nickname", style: TextStyle(color: Color(0xFFE91E63))),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveNicknames,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "Save & Continue 💞",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}