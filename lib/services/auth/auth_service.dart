// AuthService
// ─────────────────────────────────────────────────────────────
// Thin wrapper around FirebaseAuth + Firestore user profile.
//
// Currently uses Anonymous sign-in for simplicity.
// To upgrade to email/password or Google Sign-In later:
//   1. Change signInAnonymously() → signInWithEmail() or signInWithGoogle()
//   2. The user profile doc (users/{uid}) stays the same.
//   3. No other files need to change.

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // ─────────────────────────────────────────────
  // USER PROFILE (Firestore — minimal, free-tier safe)
  // ─────────────────────────────────────────────

  /// Reference to the current user's profile document.
  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(currentUser!.uid);

  /// Saves the user's display name and generates a short ID.
  /// Called once during first-time registration.
  Future<void> saveUserProfile(String displayName) async {
    // Also update Firebase Auth's displayName for convenience.
    await currentUser?.updateDisplayName(displayName);
    await currentUser?.reload();

    final shortId = _generateShortId();
    await _userDoc.set({
      'displayName': displayName,
      'shortId': shortId,
      'uid': currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Gets the user's profile data from Firestore.
  /// Returns null if no profile exists yet (first launch).
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    final snap = await _userDoc.get();
    return snap.data();
  }

  /// Gets the user's display name.
  /// Tries Firebase Auth first, then Firestore.
  Future<String?> getDisplayName() async {
    // Try Firebase Auth displayName first (cached locally).
    final authName = currentUser?.displayName;
    if (authName != null && authName.isNotEmpty) return authName;

    // Fallback to Firestore.
    final profile = await getUserProfile();
    return profile?['displayName'] as String?;
  }

  /// Gets the user's short ID from Firestore.
  Future<String?> getShortId() async {
    final profile = await getUserProfile();
    return profile?['shortId'] as String?;
  }

  /// Checks if the user has completed profile setup.
  Future<bool> hasProfile() async {
    if (currentUser == null) return false;
    final profile = await getUserProfile();
    return profile != null && profile['displayName'] != null;
  }

  /// Generates a 6-character alphanumeric short ID.
  /// Used for easy sharing between users.
  String _generateShortId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}