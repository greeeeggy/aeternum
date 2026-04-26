// lib/screens/role_selection_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'onboarding_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _isJoinMode = false;
  String? _selectedRole;
  final TextEditingController _pairIdController = TextEditingController();
  bool _isProcessing = false;
  String? _generatedPairId;
  bool _isFieldValid = false;

  @override
  void initState() {
    super.initState();
    _pairIdController.addListener(() {
      setState(() {
        _isFieldValid = _pairIdController.text.trim().isNotEmpty;
      });
    });
    _checkExistingPair();
  }

  Future<void> _checkExistingPair() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    final role = data?['role'] as String?;
    final pairId = data?['pairId'] as String?;
    final nicknames = data?['nicknames'] as List<dynamic>? ?? [];
    if (role != null && pairId != null && nicknames.isNotEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _pairIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRoleTap(String role) async {
    setState(() {
      _selectedRole = role;
    });
  }

  Future<void> _createPair(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      final pairId = const Uuid().v4();

      await FirebaseFirestore.instance.collection('couples').doc(pairId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'members': [user.uid],
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': role,
        'pairId': pairId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _generatedPairId = pairId;
        _isProcessing = false;
      });

      // Navigate to onboarding — snackbar removed because pushReplacement
      // deactivates this page immediately, crashing any ScaffoldMessenger call.
      if (mounted) {
        _navToOnboarding(role, pairId);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      // ✅ FIXED: Guard with `if (mounted)`
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e—try again?')),
        );
      }
    }
  }

  Future<void> _joinPair(String role) async {
    final pairId = _pairIdController.text.trim();
    if (pairId.isEmpty) {
      // ✅ FIXED: Guard with `if (mounted)`
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the Couple ID 💖')),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isProcessing = true);

    try {
      final coupleDoc = await FirebaseFirestore.instance.collection('couples').doc(pairId).get();
      if (!coupleDoc.exists) {
        throw Exception('Couple ID not found—double-check?');
      }
      final data = coupleDoc.data()!;
      final members = List<String>.from(data['members'] ?? []);
      if (members.length >= 2) {
        throw Exception('Pair full—start your own?');
      }
      if (members.contains(user.uid)) {
        throw Exception('Already joined—head home!');
      }

      await FirebaseFirestore.instance.collection('couples').doc(pairId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': role,
        'pairId': pairId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isProcessing = false);

      // ✅ FIXED: Guard with `if (mounted)`
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined! Syncing hearts... 💑')),
        );
        _navToOnboarding(role, pairId);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      // ✅ FIXED: Guard with `if (mounted)`
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Join failed: $e')),
        );
      }
    }
  }

  void _toggleToJoin() {
    setState(() {
      _isJoinMode = true;
      _selectedRole = null;
      _generatedPairId = null;
    });
  }

  void _navToOnboarding(String role, String pairId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OnboardingPage(role: role, pairId: pairId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 80, color: const Color(0xFFE91E63)),
              const SizedBox(height: 32),
              const Text(
                'Your Role in Our Story?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Select to connect hearts.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (!_isJoinMode) ...[
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        title: 'Boyfriend',
                        icon: Icons.man_rounded,
                        color: const Color(0xFF2196F3),
                        description: 'The guardian of surprises.',
                        onTap: () => _handleRoleTap('boyfriend'),
                        isSelected: _selectedRole == 'boyfriend',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        title: 'Girlfriend',
                        icon: Icons.woman_rounded,
                        color: const Color(0xFFE91E63),
                        description: 'The keeper of memories.',
                        onTap: () => _handleRoleTap('girlfriend'),
                        isSelected: _selectedRole == 'girlfriend',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                if (_selectedRole != null)
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _createPair(_selectedRole!),
                    icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: const Text('Create Pair & Continue'),
                  ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _toggleToJoin,
                  child: const Text(
                    'Join an existing pair?',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ] else ...[
                const Text(
                  'Enter your pair code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pairIdController,
                  decoration: InputDecoration(
                    labelText: 'Pair Code (from your partner)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: _pairIdController.text.trim().isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _pairIdController.clear(),
                    )
                        : null,
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _isJoinMode = false),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: !_isFieldValid || _isProcessing
                            ? null
                            : () => _showRoleForJoin(),
                        icon: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleForJoin() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick your role',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    title: 'Boyfriend',
                    icon: Icons.man_rounded,
                    color: const Color(0xFF2196F3),
                    description: 'The guardian.',
                    onTap: () => _joinWithRole('boyfriend'),
                    isSelected: _selectedRole == 'boyfriend',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _RoleCard(
                    title: 'Girlfriend',
                    icon: Icons.woman_rounded,
                    color: const Color(0xFFE91E63),
                    description: 'The keeper.',
                    onTap: () => _joinWithRole('girlfriend'),
                    isSelected: _selectedRole == 'girlfriend',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _joinWithRole(String role) {
    Navigator.pop(context);
    _joinPair(role);
  }
}

// _RoleCard unchanged
class _RoleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback onTap;
  final bool isSelected;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.onTap,
    required this.isSelected,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withOpacity(0.2)
                : (widget.isSelected ? widget.color.withOpacity(0.1) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withOpacity(0.8)
                  : (widget.isSelected ? widget.color : Colors.grey.shade200),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.15 : (widget.isSelected ? 0.1 : 0.05)),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(widget.icon, size: 32, color: widget.color),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.color),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}