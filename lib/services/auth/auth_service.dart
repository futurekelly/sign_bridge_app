// AuthService
// ─────────────────────────────────────────────────────────────
// Core Authentication Hub.
// Supports Google Sign-In, Email/Password, and Guest (Anonymous) login.
// All authentication flows eventually call saveUserProfile() to ensure
// the Firestore users collection has the correct shortId for call routing.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../../core/enums.dart';
import '../../data/local/hive_db.dart';
import '../webrtc/call_manager.dart';

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


  Future<bool> isUsernameUnique(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.isEmpty) return false;
    try {
      debugPrint('[AuthService] isUsernameUnique: Querying Firestore for /usernames/$clean');
      final doc = await _db.collection('usernames').doc(clean).get();
      final exists = doc.exists;
      debugPrint('[AuthService] isUsernameUnique: /usernames/$clean exists = $exists');
      return !exists;
    } catch (e) {
      debugPrint('[AuthService] isUsernameUnique: Failed with error: $e');
      rethrow;
    }
  }

  Future<User?> registerWithEmail(
      String email, String password, String displayName, String signBridgeId) async {
    final cleanUsername = signBridgeId.toLowerCase().trim();
    if (cleanUsername.isEmpty) {
      throw Exception('SignBridge ID cannot be empty');
    }

    // 1. Pre-check uniqueness to save operations and avoid orphan Auth accounts
    debugPrint('[AuthService] registerWithEmail: STEP 1 - Pre-checking uniqueness of username: $cleanUsername');
    final isUnique = await isUsernameUnique(cleanUsername);
    if (!isUnique) {
      debugPrint('[AuthService] registerWithEmail: STEP 1 FAILED - Username $cleanUsername is already taken');
      throw Exception('SignBridge ID is already taken');
    }
    debugPrint('[AuthService] registerWithEmail: STEP 1 SUCCESS - Username $cleanUsername is unique');

    UserCredential? userCred;
    try {
      // 2. Create Firebase Auth user
      debugPrint('[AuthService] registerWithEmail: STEP 2 - Creating Firebase Auth user for email: $email');
      userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User user = userCred.user!;
      debugPrint('[AuthService] registerWithEmail: STEP 2 SUCCESS - User created. UID = ${user.uid}');

      // Update display name in Auth
      debugPrint('[AuthService] registerWithEmail: Updating Auth display name to: $displayName');
      await user.updateDisplayName(displayName);
      await user.reload();

      // 3. Firestore Transaction for atomic unique validation & double write
      debugPrint('[AuthService] registerWithEmail: STEP 3 - Running transaction for usernames/$cleanUsername and users/${user.uid}');
      await _db.runTransaction((transaction) async {
        final usernameRef = _db.collection('usernames').doc(cleanUsername);
        final userDocRef = _db.collection('users').doc(user.uid);

        debugPrint('[AuthService] Transaction: Reading usernames/$cleanUsername');
        final usernameSnap = await transaction.get(usernameRef);
        if (usernameSnap.exists) {
          debugPrint('[AuthService] Transaction Check Failed: usernames/$cleanUsername already exists');
          throw Exception('SignBridge ID is already taken');
        }

        // Set usernames index doc
        debugPrint('[AuthService] Transaction: Setting usernames/$cleanUsername');
        transaction.set(usernameRef, {'uid': user.uid});

        // Set user profile doc
        debugPrint('[AuthService] Transaction: Setting users/${user.uid}');
        transaction.set(userDocRef, {
          'displayName': displayName,
          'signBridgeId': signBridgeId.trim(),
          'uid': user.uid,
          'status': 'idle',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'provider': 'email',
        });
      });
      debugPrint('[AuthService] registerWithEmail: STEP 3 SUCCESS - Transaction completed successfully');

      return _auth.currentUser;
    } catch (e) {
      debugPrint('[AuthService] registerWithEmail: STEP FAILED with error: $e');
      // 4. Rollback Auth user if transaction database write fails
      if (userCred?.user != null) {
        try {
          debugPrint('[AuthService] registerWithEmail: STEP 4 - Rollback. Deleting created Auth user: ${userCred!.user!.uid}');
          await userCred.user!.delete();
          debugPrint('[AuthService] registerWithEmail: STEP 4 SUCCESS - Auth user rolled back');
        } catch (delErr) {
          debugPrint('[AuthService] registerWithEmail: STEP 4 FAILED - Rollback deletion failed: $delErr');
        }
      }
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
      return cred.user;
    } catch (e) {
      debugPrint('[AuthService] Anonymous Login Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    // Stop the incoming-call listener so it doesn't stay active after signout.
    // If we don't cancel it here, the next login gets a duplicate/stale subscription.
    CallManager.instance.stopListening();

    // Google Sign-In isn't available on Huawei devices (no GMS), so wrap it defensively.
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthService] Google signOut failed (expected on Huawei): $e');
    }

    await _auth.signOut();

    // Drop the cached "profile is complete" answer, so the next sign-in
    // re-verifies against Firestore rather than trusting a local flag.
    //
    // Deliberately AFTER signOut, and guarded: if this ran first and threw,
    // the user would be unable to log out at all. A failed cache clear is
    // harmless — the cache is keyed by uid, so a different account ignores it.
    try {
      await clearProfileCache();
    } catch (e) {
      debugPrint('[AuthService] profile cache clear failed (harmless): $e');
    }
  }

  // ─────────────────────────────────────────────
  // USER PROFILE (Firestore)
  // ─────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(currentUser!.uid);

  /// Saves the user's display name and optional custom SignBridge ID.
  Future<void> saveUserProfile(String displayName, {String? signBridgeId, UserRole? role}) async {
    if (currentUser == null) return;

    // Update Firebase Auth's displayName if missing
    if (currentUser?.displayName == null || currentUser!.displayName!.isEmpty) {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.reload();
    }

    final existing = await getUserProfile();
    final String? activeId = existing?['signBridgeId'] as String? ?? signBridgeId;
    final String? activeRole = existing?['role'] as String? ?? role?.value;

    await _userDoc.set({
      'displayName': displayName,
      'signBridgeId': activeId,
      'role': activeRole,
      'uid': currentUser!.uid,
      'status': existing?['status'] ?? 'idle',
      'createdAt': existing?['createdAt'] ?? FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'provider': currentUser!.isAnonymous
          ? 'anonymous'
          : currentUser!.providerData.firstOrNull?.providerId ?? 'email',
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

  Future<String?> getSignBridgeId() async {
    final profile = await getUserProfile();
    return profile?['signBridgeId'] as String?;
  }

  Future<bool> hasProfile() async {
    if (currentUser == null) return false;
    final profile = await getUserProfile();
    return profile != null &&
        profile['displayName'] != null &&
        profile['displayName'].toString().trim().isNotEmpty &&
        profile['signBridgeId'] != null &&
        profile['signBridgeId'].toString().trim().isNotEmpty;
  }

  // ─────────────────────────────────────────────
  // PROFILE-COMPLETE CACHE
  // ─────────────────────────────────────────────
  //
  // hasProfile() is a Firestore round-trip, and the launch path used to await
  // it before it would move a returning user off the login screen. On a slow
  // connection that is a visible stall on every single launch, for an answer
  // that essentially never changes once it is true: registerWithEmail and
  // profile setup both write displayName and signBridgeId together, and
  // nothing in the app removes them.
  //
  // So the answer is remembered locally, keyed by uid. Keying by uid matters:
  // if a different account signs in on the same phone the stored uid will not
  // match, so it re-checks rather than inheriting the previous user's answer.
  // Signing back into the same account reuses the cache, which is exactly the
  // returning-user case this is here to make fast.
  //
  // A stale `true` is only possible if a profile is deleted server-side, which
  // nothing does. A stale `false` cannot happen: we only ever cache a `true`.

  static const String _kProfileCompleteUid = 'profileCompleteUid';

  /// Whether the signed-in user has a complete profile, answered from the
  /// local cache when possible. Falls back to (and populates from) Firestore.
  Future<bool> hasProfileCached() async {
    final user = currentUser;
    if (user == null) return false;

    if (HiveDb.settings.get(_kProfileCompleteUid) == user.uid) return true;

    final complete = await hasProfile();
    if (complete) await HiveDb.settings.put(_kProfileCompleteUid, user.uid);
    return complete;
  }

  /// Forget the cached answer. Called on sign-out so a profile completed on
  /// this device is re-verified the next time an account signs in, rather than
  /// being trusted indefinitely.
  Future<void> clearProfileCache() async {
    await HiveDb.settings.delete(_kProfileCompleteUid);
  }
}