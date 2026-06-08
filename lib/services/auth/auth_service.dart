// AuthService
// ─────────────────────────────────────────────────────────────
// Core Authentication Hub.
// Supports Google Sign-In, Email/Password, and Guest (Anonymous) login.
// All authentication flows eventually call saveUserProfile() to ensure
// the Firestore users collection has the correct shortId for call routing.

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (used by gating UI if needed).
  Stream<User?> get authState => _auth.authStateChanges();

  // ─────────────────────────────────────────────
  // 1. GOOGLE SIGN-IN
  // ─────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // The user canceled the sign-in
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      
      // Ensure profile exists in Firestore (using Google's display name)
      if (userCred.user != null) {
        final name = userCred.user!.displayName ?? 'Google User';
        await saveUserProfile(name);
      }
      
      return userCred.user;
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In Error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 2. EMAIL & PASSWORD AUTH
  // ─────────────────────────────────────────────
  Future<User?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCred.user != null) {
        // Save to Firebase Auth profile
        await userCred.user!.updateDisplayName(displayName);
        await userCred.user!.reload();
        // Save to Firestore profile
        await saveUserProfile(displayName);
      }
      return _auth.currentUser;
    } catch (e) {
      debugPrint('[AuthService] Email Registration Error: $e');
      rethrow;
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCred.user;
    } catch (e) {
      debugPrint('[AuthService] Email Login Error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 3. GUEST (ANONYMOUS) AUTH
  // ─────────────────────────────────────────────
  Future<User?> signInAnonymously() async {
    if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
      return _auth.currentUser;
    }
    try {
      final cred = await _auth.signInAnonymously();
      // We do not save a profile here immediately, the LoginScreen handles it
      // so it can assign the 'Guest' name.
      return cred.user;
    } catch (e) {
      debugPrint('[AuthService] Anonymous Login Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────
  // USER PROFILE (Firestore)
  // ─────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(currentUser!.uid);

  /// Saves the user's display name and generates a short ID.
  /// Uses SetOptions(merge: true) so it doesn't overwrite an existing shortId
  /// if a returning user signs in again.
  Future<void> saveUserProfile(String displayName) async {
    if (currentUser == null) return;
    
    // Update Firebase Auth's displayName if missing
    if (currentUser?.displayName == null || currentUser!.displayName!.isEmpty) {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.reload();
    }

    // Check if profile already exists to preserve shortId
    final existing = await getUserProfile();
    final String shortId = existing?['shortId'] as String? ?? _generateShortId();

    await _userDoc.set({
      'displayName': displayName,
      'shortId': shortId,
      'uid': currentUser!.uid,
      'createdAt': existing?['createdAt'] ?? FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'provider': currentUser!.isAnonymous ? 'anonymous' : currentUser!.providerData.firstOrNull?.providerId ?? 'email',
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    final snap = await _userDoc.get();
    return snap.data();
  }

  Future<String?> getDisplayName() async {
    final authName = currentUser?.displayName;
    if (authName != null && authName.isNotEmpty) return authName;
    final profile = await getUserProfile();
    return profile?['displayName'] as String?;
  }

  Future<String?> getShortId() async {
    final profile = await getUserProfile();
    return profile?['shortId'] as String?;
  }

  Future<bool> hasProfile() async {
    if (currentUser == null) return false;
    final profile = await getUserProfile();
    return profile != null && profile['displayName'] != null;
  }

  String _generateShortId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}