// AuthService
// ─────────────────────────────────────────────────────────────
// Thin wrapper around FirebaseAuth.
// For the demo we use Anonymous sign-in: simple, no email/password
// flow needed, but each device still gets a unique uid that the
// signaling layer can use as a peer identifier.

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (used by gating UI if needed).
  Stream<User?> get authState => _auth.authStateChanges();

  /// Anonymous sign-in. Returns the signed-in user.
  Future<User?> signInAnonymously() async {
    if (_auth.currentUser != null) return _auth.currentUser;
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}