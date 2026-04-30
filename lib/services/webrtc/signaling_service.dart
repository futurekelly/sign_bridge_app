// SignalingService
// ─────────────────────────────────────────────────────────────
// Bridges WebRTCService ↔ Firestore.
//
// Flow:
//
//   CALLER                                           CALLEE
//   ──────                                           ──────
//   createCall()                                     joinCall(callId)
//      │                                                 │
//      │  writes offer SDP            reads offer SDP   │
//      │  → calls/{id}.offer          ← calls/{id}      │
//      │                                                 │
//      │                              writes answer SDP  │
//      │  ← calls/{id}.answer         → calls/{id}      │
//      │                                                 │
//      │  writes ICE → callerCandidates/                 │
//      │  reads ICE  ← calleeCandidates/                 │
//      │  (mirror on callee side)                        │
//
// IMPORTANT: this service knows NOTHING about media or AI.
// It only moves text JSON through Firestore.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../firebase/firestore_service.dart';
import 'webrtc_service.dart';

enum SignalingRole { caller, callee }

class SignalingService {
  final WebRTCService webrtc;
  final String selfId;

  SignalingRole? _role;
  String? _callId;
  String? get callId => _callId;

  // Active stream subscriptions to clean up on dispose.
  StreamSubscription? _callDocSub;
  StreamSubscription? _candidatesSub;

  SignalingService({required this.webrtc, required this.selfId});

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  /// CALLER side: creates a new call document and emits an SDP offer.
  /// Returns the generated callId (share this with the peer).
  Future<String> createCall() async {
    _role = SignalingRole.caller;

    // 1) Create a fresh call document.
    final docRef = FirestoreService.callsRef.doc();
    _callId = docRef.id;
    await docRef.set({
      'callerId': selfId,
      'calleeId': null,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) Wire WebRTC callbacks → Firestore writes.
    webrtc.onLocalSdpReady = (RTCSessionDescription sdp) async {
      await docRef.update({
        'offer': {'sdp': sdp.sdp, 'type': sdp.type},
      });
    };
    webrtc.onLocalIceCandidate = (RTCIceCandidate c) async {
      await FirestoreService.callerCandidates(_callId!).add(_candToMap(c));
    };

    // 3) Generate offer (this triggers onLocalSdpReady above).
    await webrtc.createOffer();

    // 4) Listen for answer + remote ICE.
    _listenForAnswer(docRef);
    _listenRemoteCandidates(FirestoreService.calleeCandidates(_callId!));

    return _callId!;
  }

  /// CALLEE side: joins an existing call by ID.
  Future<void> joinCall(String callId) async {
    _role = SignalingRole.callee;
    _callId = callId;
    final docRef = FirestoreService.callDoc(callId);

    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception('Call $callId not found');
    }

    // 1) Mark as joined.
    await docRef.update({
      'calleeId': selfId,
      'status': 'active',
    });

    // 2) Wire callbacks for our own SDP/ICE.
    webrtc.onLocalSdpReady = (RTCSessionDescription sdp) async {
      await docRef.update({
        'answer': {'sdp': sdp.sdp, 'type': sdp.type},
      });
    };
    webrtc.onLocalIceCandidate = (RTCIceCandidate c) async {
      await FirestoreService.calleeCandidates(callId).add(_candToMap(c));
    };

    // 3) Read the offer that the caller already wrote.
    final data = snap.data();
    final offerMap = data?['offer'];
    if (offerMap == null) {
      throw Exception('Call has no offer yet');
    }
    final offer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);

    // 4) Apply the offer and create our answer (this triggers onLocalSdpReady).
    await webrtc.handleRemoteOffer(offer);

    // 5) Listen for caller ICE candidates.
    _listenRemoteCandidates(FirestoreService.callerCandidates(callId));
  }

  /// Ends the call: marks status and stops listeners.
  Future<void> endCall() async {
    if (_callId != null) {
      try {
        await FirestoreService.callDoc(_callId!).update({'status': 'ended'});
      } catch (_) {/* best-effort */}
    }
    await dispose();
  }

  Future<void> dispose() async {
    await _callDocSub?.cancel();
    await _candidatesSub?.cancel();
    _callDocSub = null;
    _candidatesSub = null;
  }

  // ─────────────────────────────────────────────
  // INTERNAL LISTENERS
  // ─────────────────────────────────────────────

  /// Caller listens for the answer SDP appearing on the call doc.
  void _listenForAnswer(DocumentReference<Map<String, dynamic>> docRef) {
    _callDocSub = docRef.snapshots().listen((snap) async {
      final data = snap.data();
      if (data == null) return;
      final answerMap = data['answer'];
      if (answerMap != null) {
        final answer = RTCSessionDescription(answerMap['sdp'], answerMap['type']);
        await webrtc.handleRemoteAnswer(answer);
      }
    });
  }

  /// Either side: subscribes to the OPPOSITE party's ICE candidate collection.
  void _listenRemoteCandidates(
      CollectionReference<Map<String, dynamic>> collection) {
    _candidatesSub = collection.snapshots().listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final m = change.doc.data();
          if (m == null) continue;
          await webrtc.addRemoteIceCandidate(
            RTCIceCandidate(
              m['candidate'],
              m['sdpMid'],
              m['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  Map<String, dynamic> _candToMap(RTCIceCandidate c) => {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      };
}