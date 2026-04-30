// LoginScreen (Phase 3) — uses anonymous Firebase Auth.

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
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // If already signed-in (hot restart, etc.), skip straight to home.
    if (_auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signInAnonymously();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sign_language,
                  size: 96, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(AppConstants.appTagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 64),

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
                    : const Text('Continue'),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 12),
              const Text(
                '🔐 Anonymous Firebase Auth (demo mode)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}