import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // NEW: For stub doc
import 'dart:developer' as developer;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // DEV: Force account picker for testing (toggle false for prod auto-select)
      final bool forcePicker = kDebugMode;  // Set to true for always-prompt during dev

      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        // Force account selection on web via OAuth param
        if (forcePicker) {
          googleProvider.setCustomParameters({'prompt': 'select_account'});
        }
        await FirebaseAuth.instance.signInWithRedirect(googleProvider);
        debugPrint('Web: Redirect initiated (picker forced: $forcePicker)');
        return;  // Handled by authStateChanges
      } else {
        // Mobile: Clear session to force picker
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/classroom.courses.readonly',
            'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
            'https://www.googleapis.com/auth/classroom.announcements.readonly',
          ],
        );
        if (forcePicker) {
          await googleSignIn.signOut();  // Or use .disconnect() for full reset
          debugPrint('Mobile: Signed out to force picker');
        }

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          setState(() => _errorMessage = 'Sign-in cancelled');
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // NEW: Stub user doc (triggers onboarding check in AuthWrapper)
      final user = FirebaseAuth.instance.currentUser!;
      debugPrint('Sign-in Success: UID=${user.uid} | Email=${user.email} | Picker forced: $forcePicker');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'createdAt': FieldValue.serverTimestamp(),
            'photoURL': user.photoURL,
            'displayName': user.displayName,
          }, SetOptions(merge: true));

      // No manual nav—AuthWrapper routes based on doc
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _getErrorMessage(e.code));
      debugPrint('Google sign-in error: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
      debugPrint('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildSignInContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Signing in...', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildSignInContent() {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCustomGoogleSignIn(),
                if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        final GoogleSignIn googleSignIn = GoogleSignIn();
                        await googleSignIn.signOut();  // Or .disconnect()
                        await FirebaseAuth.instance.signOut();
                        debugPrint('Switched account: Signed out for fresh picker');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signed out—tap Google to pick new account')),
                          );
                        }
                      },
                      child: const Text('🔄 Switch Account (Dev Only)'),
                    ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'By signing in, you agree to our Terms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomGoogleSignIn() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[700],
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.g_mobiledata, size: 24),
            SizedBox(width: 12),
            Text('Sign in with Google'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, [BoxConstraints? constraints, double? maxHeight]) {
    final availableHeight = (maxHeight ?? (constraints?.maxHeight ?? 200)).clamp(0.0, double.infinity);
    final availableWidth = constraints?.maxWidth ?? MediaQuery.of(context).size.width;
    final isCompact = availableHeight < 100 || MediaQuery.of(context).size.height < 600;

    return RepaintBoundary(
      child: ClipRect(
        child: FittedBox(
          fit: isCompact ? BoxFit.scaleDown : BoxFit.contain,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: availableHeight,
              maxWidth: availableWidth,
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8E1E9), Color(0xFFE8F5E8)],
                ),
              ),
              padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 12),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isCompact)
                    const CouplesHeartAnimation(size: 40, isCompact: false)
                  else
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 28, color: Color(0xFFE96D88)),
                        SizedBox(width: 2),
                        Icon(Icons.favorite, size: 28, color: Color(0xFFC2185B)),
                      ],
                    ),
                  SizedBox(height: isCompact ? 4 : 8),
                  Text(
                    "Aeternum ❤️",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: isCompact ? 14 : 18,
                    ),
                  ),
                  SizedBox(height: isCompact ? 2 : 4),
                  Flexible(
                    child: Text(
                      "Sign in with Google for your forever",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// CouplesHeartAnimation remains unchanged
class CouplesHeartAnimation extends StatefulWidget {
  final double size;
  final bool isCompact;

  const CouplesHeartAnimation({super.key, required this.size, required this.isCompact});

  @override
  State<CouplesHeartAnimation> createState() => _CouplesHeartAnimationState();
}

class _CouplesHeartAnimationState extends State<CouplesHeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: widget.size, color: const Color(0xFFE96D88)),
              Transform.translate(
                offset: const Offset(4, 0),
                child: Icon(Icons.favorite, size: widget.size, color: const Color(0xFFC2185B)),
              ),
            ],
          ),
        );
      },
    );
  }
}