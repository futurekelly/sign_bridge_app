// LoginScreen — Anonymous auth + display name registration.
// First-time users enter a display name; returning users auto-skip to home.

import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../services/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _nameController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _isReturningUser = false;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  /// If already signed-in AND has a profile, skip to home.
  Future<void> _checkExistingUser() async {
    if (_auth.currentUser != null) {
      final hasProfile = await _auth.hasProfile();
      if (hasProfile && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        return;
      }
      // Signed in but no profile yet — show name input.
      if (mounted) {
        setState(() => _isReturningUser = true);
      }
    }
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 1) Sign in anonymously (or reuse existing session).
      await _auth.signInAnonymously();

      // 2) Save display name + generate short ID.
      await _auth.saveUserProfile(name);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Skip registration — sign in anonymously without a name.
  Future<void> _continueAsGuest() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _auth.signInAnonymously();
      await _auth.saveUserProfile('Guest');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo + branding ──
                const Icon(Icons.sign_language,
                    size: 80, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(AppConstants.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),

                const SizedBox(height: 48),

                // ── Name input ──
                const Text(
                  'What should we call you?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  autofocus: !_isReturningUser,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Enter your display name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppTheme.surface,
                  ),
                  onSubmitted: (_) => _continue(),
                ),

                const SizedBox(height: 20),

                // ── Continue button ──
                ElevatedButton(
                  onPressed: _busy ? null : _continue,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Get Started'),
                ),

                const SizedBox(height: 12),

                // ── Guest option ──
                TextButton(
                  onPressed: _busy ? null : _continueAsGuest,
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                ],

                const SizedBox(height: 12),
                const Text(
                  'Your name will be shown to other users during calls.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}