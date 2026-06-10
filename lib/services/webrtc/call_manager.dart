import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../core/routes.dart';
import '../../core/enums.dart';
import '../../ui/widgets/incoming_call_overlay.dart';

class CallManager {
  static final CallManager instance = CallManager._internal();
  CallManager._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _incomingCallSub;

  // Stream for UI components to listen to incoming calls
  final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incomingCalls => _incomingCallController.stream;

  /// Starts listening for incoming calls targeting the current user.
  void startListening() {
    final user = _auth.currentUser;
    debugPrint('[CallManager] startListening invoked.');
    if (user == null) {
      debugPrint('[CallManager] startListening aborted: FirebaseAuth currentUser is NULL.');
      return;
    }

    debugPrint('[CallManager] startListening: Setting up listener for UID: ${user.uid}');
    debugPrint('[CallManager] startListening: Query targeting calleeId == ${user.uid} and status == dialing');

    // Self-healing check: recover from any crash/stale busy state
    recoverStaleBusyState();

    _incomingCallSub?.cancel();
    _incomingCallSub = _db
        .collection('calls')
        .where('calleeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'dialing')
        .snapshots()
        .listen((snap) async {
      debugPrint('[CallManager] Incoming call stream snapshot received. Documents count: ${snap.docs.length}');
      for (final change in snap.docChanges) {
        debugPrint('[CallManager] Document change detected: type = ${change.type}, doc ID = ${change.doc.id}');
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) {
            debugPrint('[CallManager] Document data is NULL for doc ID: ${change.doc.id}');
            continue;
          }

          final String callId = change.doc.id;
          final String callerId = data['callerId'] ?? '';
          debugPrint('[CallManager] Incoming call detected. Call ID: $callId, Caller ID: $callerId, Callee ID: ${data['calleeId']}, Status: ${data['status']}');

          // Fetch caller profile to display details
          debugPrint('[CallManager] Fetching caller profile from: /users/$callerId');
          final callerSnap = await _db.collection('users').doc(callerId).get();
          final callerName = callerSnap.data()?['displayName'] ?? 'SignBridge User';
          final callerRole = callerSnap.data()?['role'] ?? 'both';
          debugPrint('[CallManager] Caller profile fetched. Name: $callerName, Role: $callerRole');

          // Listener for call timeout or cancellations
          StreamSubscription? docSub;
          debugPrint('[CallManager] Subscribing to call document lifecycle: /calls/$callId');
          docSub = _db.collection('calls').doc(callId).snapshots().listen((docSnap) {
            if (!docSnap.exists) {
              debugPrint('[CallManager] Call document /calls/$callId deleted. Dismissing overlay.');
              IncomingCallOverlay.dismiss();
              docSub?.cancel();
              return;
            }
            final status = docSnap.data()?['status'];
            debugPrint('[CallManager] Call document /calls/$callId status update: $status');
            if (status != 'dialing' && status != 'accepted') {
              debugPrint('[CallManager] Call status changed to $status. Dismissing overlay.');
              IncomingCallOverlay.dismiss();
              docSub?.cancel();
            }
          });

          debugPrint('[CallManager] Triggering IncomingCallOverlay.show for Call ID: $callId');
          IncomingCallOverlay.show(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerRole: callerRole,
            onAccept: () async {
              debugPrint('[CallManager] User accepted the call. Cleaning overlay listeners.');
              docSub?.cancel();
              await acceptCall(callId);
              AppRoutes.navigatorKey.currentState?.pushNamed(
                AppRoutes.call,
                arguments: CallArgs(role: CallRole.callee, callId: callId, peerUid: callerId),
              );
            },
            onDecline: () async {
              debugPrint('[CallManager] User declined the call. Cleaning overlay listeners.');
              docSub?.cancel();
              await rejectCall(callId, user.uid, callerId);
            },
          );
        }
      }
    }, onError: (error) {
      debugPrint('[CallManager] Incoming call stream error: $error');
    });
  }

  /// Self-healing presence check: recovers the user to 'idle' if their state is stuck as 'busy'
  /// but no active signaling document exists in Firestore involving their UID.
  Future<void> recoverStaleBusyState() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      if (!userSnap.exists) return;

      final userData = userSnap.data()!;
      final status = userData['status'] ?? 'idle';

      if (status == 'busy') {
        // Query to check if an active call document exists involving this user
        final callerQuery = await _db
            .collection('calls')
            .where('callerId', isEqualTo: uid)
            .limit(1)
            .get();

        final calleeQuery = await _db
            .collection('calls')
            .where('calleeId', isEqualTo: uid)
            .limit(1)
            .get();

        if (callerQuery.docs.isEmpty && calleeQuery.docs.isEmpty) {
          // No active calls exist, the status is stale. Safely restore to idle.
          await _db.collection('users').doc(uid).update({
            'status': 'idle',
            'lastSeen': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Just update presence heartbeat timestamp
        await _db.collection('users').doc(uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[CallManager] Error running stale state recovery: $e');
    }
  }

  void stopListening() {
    _incomingCallSub?.cancel();
    _incomingCallSub = null;
  }

  /// Resolves a SignBridge ID (username) to a Firebase UID.
  /// Returns null if not found.
  Future<String?> resolveSignBridgeId(String id) async {
    try {
      final snap = await _db.collection('usernames').doc(id.toLowerCase().trim()).get();
      if (snap.exists) {
        return snap.data()?['uid'] as String?;
      }
    } catch (e) {
      debugPrint('[CallManager] Error resolving SignBridge ID: $e');
    }
    return null;
  }

  /// Cancel call - triggers when the caller cancels during dialing
  Future<void> cancelCall(String callId, String callerUid, String calleeUid) async {
    String callerName = 'User';
    String calleeName = 'User';
    try {
      final callerSnap = await _db.collection('users').doc(callerUid).get();
      final calleeSnap = await _db.collection('users').doc(calleeUid).get();
      callerName = callerSnap.data()?['displayName'] ?? 'User';
      calleeName = calleeSnap.data()?['displayName'] ?? 'User';
    } catch (_) {}

    await _db.runTransaction((transaction) async {
      final callRef = _db.collection('calls').doc(callId);
      final calleeRef = _db.collection('users').doc(calleeUid);
      final callerRef = _db.collection('users').doc(callerUid);

      transaction.update(callRef, {'status': 'caller_cancelled'});
      transaction.update(calleeRef, {'status': 'idle'});
      transaction.update(callerRef, {'status': 'idle'});
    });

    // Save history records: caller cancelled is logged as a missed call
    await saveCallHistory(uid: callerUid, peerUid: calleeUid, peerName: calleeName, callType: 'missed', durationSeconds: 0);
    await saveCallHistory(uid: calleeUid, peerUid: callerUid, peerName: callerName, callType: 'missed', durationSeconds: 0);

    await _cleanupCandidates(callId);
  }

  /// Atomically initiates a call. Checks if callee is idle, sets caller to busy, callee to ringing, and creates the call doc.
  /// Returns the generated call ID if successful.
  Future<String> initiateCall(String calleeUid) async {
    final callerUid = _auth.currentUser?.uid;
    if (callerUid == null) throw Exception('User not authenticated');

    final callId = _db.collection('calls').doc().id;
    final callPath = 'calls/$callId';
    debugPrint('[CallManager] initiateCall: Generating Call ID: $callId, Target Callee UID: $calleeUid');
    debugPrint('[CallManager] initiateCall: Exact Firestore document path to write: $callPath');

    await _db.runTransaction((transaction) async {
      final calleeRef = _db.collection('users').doc(calleeUid);
      final callerRef = _db.collection('users').doc(callerUid);

      debugPrint('[CallManager] initiateCall (Transaction): Reading callee profile /users/$calleeUid');
      final calleeSnap = await transaction.get(calleeRef);
      if (!calleeSnap.exists) {
        debugPrint('[CallManager] initiateCall (Transaction) FAILED: Callee /users/$calleeUid doc not found');
        throw Exception('Callee profile not found');
      }

      final calleeData = calleeSnap.data()!;
      final calleeStatus = calleeData['status'] ?? 'idle';
      debugPrint('[CallManager] initiateCall (Transaction): Callee current status: $calleeStatus');
      if (calleeStatus != 'idle') {
        debugPrint('[CallManager] initiateCall (Transaction) FAILED: Callee busy on status: $calleeStatus');
        throw Exception('User is currently busy on another call');
      }

      // Mark caller as busy and callee as ringing (Refinement 1)
      debugPrint('[CallManager] initiateCall (Transaction): Updating caller (/users/$callerUid) status to busy and callee (/users/$calleeUid) status to ringing');
      transaction.update(callerRef, {'status': 'busy'});
      transaction.update(calleeRef, {'status': 'ringing'});

      // Create the call document
      final callDocRef = _db.collection('calls').doc(callId);
      debugPrint('[CallManager] initiateCall (Transaction): Creating call document at $callPath');
      transaction.set(callDocRef, {
        'callerId': callerUid,
        'calleeId': calleeUid,
        'status': 'dialing',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    debugPrint('[CallManager] initiateCall SUCCESS: Call created at $callPath');
    return callId;
  }

  /// Accept call - updates callee status to busy and changes call status to accepted
  Future<void> acceptCall(String callId) async {
    final calleeUid = _auth.currentUser?.uid;
    if (calleeUid == null) return;

    await _db.runTransaction((transaction) async {
      final callRef = _db.collection('calls').doc(callId);
      final calleeRef = _db.collection('users').doc(calleeUid);

      transaction.update(callRef, {'status': 'accepted'});
      transaction.update(calleeRef, {'status': 'busy'}); // Both are busy now
    });
  }

  /// Reject call - resets both profiles and logs a declined call
  Future<void> rejectCall(String callId, String calleeUid, String callerUid) async {
    // 1. Fetch profiles to get names for the call history logs
    String callerName = 'User';
    String calleeName = 'User';
    try {
      final callerSnap = await _db.collection('users').doc(callerUid).get();
      final calleeSnap = await _db.collection('users').doc(calleeUid).get();
      callerName = callerSnap.data()?['displayName'] ?? 'User';
      calleeName = calleeSnap.data()?['displayName'] ?? 'User';
    } catch (_) {}

    await _db.runTransaction((transaction) async {
      final callRef = _db.collection('calls').doc(callId);
      final calleeRef = _db.collection('users').doc(calleeUid);
      final callerRef = _db.collection('users').doc(callerUid);

      transaction.update(callRef, {'status': 'rejected'});
      transaction.update(calleeRef, {'status': 'idle'});
      transaction.update(callerRef, {'status': 'idle'});
    });

    // 2. Save history records (Refinement 2)
    await saveCallHistory(uid: callerUid, peerUid: calleeUid, peerName: calleeName, callType: 'declined', durationSeconds: 0);
    await saveCallHistory(uid: calleeUid, peerUid: callerUid, peerName: callerName, callType: 'declined', durationSeconds: 0);

    await _cleanupCandidates(callId);
  }

  /// End call and clean up candidates - logs completed call
  Future<void> endCall(String callId, String calleeUid, String callerUid, {int durationSeconds = 0}) async {
    String callerName = 'User';
    String calleeName = 'User';
    try {
      final callerSnap = await _db.collection('users').doc(callerUid).get();
      final calleeSnap = await _db.collection('users').doc(calleeUid).get();
      callerName = callerSnap.data()?['displayName'] ?? 'User';
      calleeName = calleeSnap.data()?['displayName'] ?? 'User';
    } catch (_) {}

    await _db.runTransaction((transaction) async {
      final callRef = _db.collection('calls').doc(callId);
      final calleeRef = _db.collection('users').doc(calleeUid);
      final callerRef = _db.collection('users').doc(callerUid);

      transaction.update(callRef, {'status': 'ended'});
      transaction.update(calleeRef, {'status': 'idle'});
      transaction.update(callerRef, {'status': 'idle'});
    });

    // Log call as completed
    await saveCallHistory(uid: callerUid, peerUid: calleeUid, peerName: calleeName, callType: 'outgoing', durationSeconds: durationSeconds);
    await saveCallHistory(uid: calleeUid, peerUid: callerUid, peerName: callerName, callType: 'incoming', durationSeconds: durationSeconds);

    // Clean up candidates asynchronously
    await _cleanupCandidates(callId);
  }

  /// Timeout call - resets both profiles and logs a missed call
  Future<void> timeoutCall(String callId, String calleeUid, String callerUid) async {
    String callerName = 'User';
    String calleeName = 'User';
    try {
      final callerSnap = await _db.collection('users').doc(callerUid).get();
      final calleeSnap = await _db.collection('users').doc(calleeUid).get();
      callerName = callerSnap.data()?['displayName'] ?? 'User';
      calleeName = calleeSnap.data()?['displayName'] ?? 'User';
    } catch (_) {}

    await _db.runTransaction((transaction) async {
      final callRef = _db.collection('calls').doc(callId);
      final calleeRef = _db.collection('users').doc(calleeUid);
      final callerRef = _db.collection('users').doc(callerUid);

      transaction.update(callRef, {'status': 'timed_out'});
      transaction.update(calleeRef, {'status': 'idle'});
      transaction.update(callerRef, {'status': 'idle'});
    });

    // Save missed call logs
    await saveCallHistory(uid: callerUid, peerUid: calleeUid, peerName: calleeName, callType: 'missed', durationSeconds: 0);
    await saveCallHistory(uid: calleeUid, peerUid: callerUid, peerName: callerName, callType: 'missed', durationSeconds: 0);

    await _cleanupCandidates(callId);
  }

  /// Adds a call log under the user's Firestore collection.
  Future<void> saveCallHistory({
    required String uid,
    required String peerUid,
    required String peerName,
    required String callType, // 'incoming' | 'outgoing' | 'missed' | 'declined'
    required int durationSeconds,
  }) async {
    try {
      await _db.collection('users').doc(uid).collection('call_history').add({
        'peerId': peerUid,
        'peerName': peerName,
        'callType': callType,
        'durationSeconds': durationSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[CallManager] Failed to write history record: $e');
    }
  }

  Future<void> _cleanupCandidates(String callId) async {
    try {
      final callerCandidates = _db.collection('calls').doc(callId).collection('callerCandidates');
      final calleeCandidates = _db.collection('calls').doc(callId).collection('calleeCandidates');

      final callerSnap = await callerCandidates.get();
      final calleeSnap = await calleeCandidates.get();

      final batch = _db.batch();
      for (final doc in callerSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in calleeSnap.docs) {
        batch.delete(doc.reference);
      }

      // Delete signaling document
      batch.delete(_db.collection('calls').doc(callId));

      await batch.commit();
    } catch (e) {
      debugPrint('Failed to clean up WebRTC candidates: $e');
    }
  }
}
