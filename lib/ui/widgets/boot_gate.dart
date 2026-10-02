// BootGate — decides the first screen before the login form is ever built.
//
// WHY THIS EXISTS
//
// The app used to always start at /login and let LoginScreen figure out that
// the user was already signed in. That reads as a bug to the user: the login
// form appears, sits there while credentials are "verified", and only then
// jumps to the dashboard. Two separate things caused the wait:
//
//   1. app.dart set initialRoute = AppRoutes.login unconditionally, so
//      LoginScreen was built and painted even for a signed-in user.
//   2. LoginScreen._checkExistingUser() then awaited TWO sequential Firestore
//      round-trips — hasProfile(), then getUserProfile() — before navigating.
//      On a slow connection that is seconds of staring at a login form the
//      user does not need and cannot use.
//
// There was also a latent bug in that arrangement: _checkExistingUser() ran
// once from initState and checked `currentUser` synchronously. If the SDK had
// not finished restoring the persisted session at that instant, it silently
// did nothing, and the signed-in user was left sitting on the login form
// permanently.
//
// WHAT THIS DOES INSTEAD
//
// The decision is made once, here, before any screen is built, and the login
// form is only ever constructed for a genuinely signed-out user. The fast path
// is a synchronous read of FirebaseAuth.instance.currentUser, which after
// Firebase.initializeApp() is normally already populated from disk — so a
// returning user reaches the dashboard without a network read at all. The slow
// path waits for the first authoritative authStateChanges() event rather than
// guessing, which fixes the latent bug above.
//
// This runs on every launch, so it must stay cheap. The only thing allowed to
// block the first frame is the local profile cache (see
// AuthService.hasProfileCached); the role re-sync deliberately runs *after*
// navigation so a slow network cannot hold up the dashboard.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/accessibility_controller.dart';
import '../../core/enums.dart';
import '../../services/auth/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/profile_setup_screen.dart';

class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  /// The screen to show. Null while still deciding.
  Widget? _next;

  /// Background colours of the native splash. These MUST match `color` and
  /// `color_dark` in pubspec.yaml's flutter_native_splash block. If they
  /// drift, the native splash hands over to a differently-coloured Flutter
  /// frame and the user sees a flash on every cold start.
  static const Color _splashLight = Color(0xFF2563EB);
  static const Color _splashDark = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    unawaited(_decide());
  }

  Future<void> _decide() async {
    // A first-ever launch goes to the intro slides regardless of auth state.
    if (!OnboardingScreen.hasSeenOnboarding) {
      _show(const OnboardingScreen());
      return;
    }

    // ── Fast path ──────────────────────────────────────────────────────────
    // After Firebase.initializeApp() the persisted session is normally already
    // available synchronously, so this is where a returning user is handled
    // and no network call happens at all.
    var user = FirebaseAuth.instance.currentUser;

    // ── Slow path ─────────────────────────────────────────────────────────
    // The session has not been restored yet. Wait for the SDK's first
    // authoritative answer instead of assuming signed-out, which is the bug
    // the old LoginScreen._checkExistingUser() had.
    if (user == null) {
      try {
        user = await FirebaseAuth.instance.authStateChanges().first;
      } catch (e) {
        debugPrint('[BootGate] authStateChanges failed, assuming signed out: $e');
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (!mounted) return;

    if (user == null) {
      _show(const LoginScreen());
      return;
    }

    // Local Hive read in the common case; Firestore only on a cache miss.
    //
    // The catch matters: whatever happens here, the app must not leave the
    // user staring at the splash colour forever. A signed-in user whose
    // profile we could not confirm is far better served by the dashboard —
    // which loads its own name and history with its own error handling — than
    // by a permanent loading screen.
    bool hasProfile;
    try {
      hasProfile = await AuthService().hasProfileCached();
    } catch (e) {
      debugPrint('[BootGate] profile check failed, falling back to home: $e');
      hasProfile = true;
    }

    if (!mounted) return;

    _show(hasProfile ? const HomeScreen() : const ProfileSetupScreen());

    // The locally-stored role can be stale if it was last changed on another
    // device, so refresh it — but off the critical path, after the dashboard
    // is already on screen. The previous code awaited this before navigating,
    // which is what made every launch feel slow.
    unawaited(_syncRole());
  }

  Future<void> _syncRole() async {
    try {
      final profile = await AuthService().getUserProfile();
      final roleStr = profile?['role'] as String?;
      if (roleStr == null || !mounted) return;
      await context.read<AccessibilityController>().setRole(
            UserRoleX.fromString(roleStr),
          );
    } catch (e) {
      // Non-fatal: the role persisted on this device is already in use.
      debugPrint('[BootGate] background role sync skipped: $e');
    }
  }

  void _show(Widget screen) {
    if (mounted) setState(() => _next = screen);
  }

  @override
  Widget build(BuildContext context) {
    final screen = _next;
    if (screen != null) return screen;

    // Still deciding. This paints the same solid colour and glyph as the
    // native splash so the hand-off from the launch screen is invisible
    // rather than a flash of an unrelated background.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _splashDark : _splashLight,
      body: const Center(
        child: Icon(Icons.sign_language, size: 96, color: Colors.white),
      ),
    );
  }
}
