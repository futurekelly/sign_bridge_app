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
//
// ── Fix (May 2026) ──────────────────────────────────────────
// • Added _answerApplied guard: Firestore doc snapshots fire
//   every time any field on the call doc is updated (e.g. when
//   the caller later writes its own ICE candidates sub-collection
//   changes can sometimes re-trigger the parent listener via
//   compound queries, or more commonly when calleeId/status is
//   updated). Without the guard, handleRemoteAnswer() is called
//   a second time on an already-stable PeerConnection, which
//   throws an InvalidStateError and breaks the connection.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../firebase/firestore_service.dart';
import 'webrtc_service.dart';

class SignalingService {
  final WebRTCService webrtc;
  final String selfId;

  String? _callId;
  String? get callId => _callId;

  // Guard: ensures handleRemoteAnswer is called exactly once.
  bool _answerApplied = false;

  // Active stream subscriptions to clean up on dispose.
  StreamSubscription? _callDocSub;
  StreamSubscription? _candidatesSub;

  SignalingService({required this.webrtc, required this.selfId});

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  /// CALLER side: Configures signaling for a pre-created callId and emits an SDP offer.
  Future<void> createCall(String callId) async {
    _answerApplied = false;
    _callId = callId;

    final docRef = FirestoreService.callsRef.doc(callId);

    // 1) Wire WebRTC callbacks → Firestore updates.
    webrtc.onLocalSdpReady = (RTCSessionDescription sdp) async {
      await docRef.update({
        'offer': {'sdp': sdp.sdp, 'type': sdp.type},
      });
    };
    webrtc.onLocalIceCandidate = (RTCIceCandidate c) async {
      await FirestoreService.callerCandidates(_callId!).add(_candToMap(c));
    };

    // 2) Generate offer (this triggers onLocalSdpReady above).
    await webrtc.createOffer();

    // 3) Listen for answer + remote ICE.
    _listenForAnswer(docRef);
    _listenRemoteCandidates(FirestoreService.calleeCandidates(_callId!));
  }

  /// CALLEE side: joins an existing call by ID.
  Future<void> joinCall(String callId) async {
    _callId = callId;
    _answerApplied = false;
    final docRef = FirestoreService.callDoc(callId);

    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception('Call $callId not found');
    }

    // 1) Mark as accepted.
    await docRef.update({
      'status': 'accepted',
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

    // 3) Read the offer. If it doesn't exist yet, listen for it real-time.
    final data = snap.data();
    final offerMap = data?['offer'];
    if (offerMap != null) {
      final offer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);
      // 4) Apply the offer and create our answer (this triggers onLocalSdpReady).
      await webrtc.handleRemoteOffer(offer);
      // 5) Listen for caller ICE candidates.
      _listenRemoteCandidates(FirestoreService.callerCandidates(callId));
    } else {
      debugPrint('[Signaling] Call has no offer yet. Waiting for caller to write offer...');
      final completer = Completer<void>();
      StreamSubscription? tempSub;

      tempSub = docRef.snapshots().listen((docSnap) async {
        final d = docSnap.data();
        if (d != null && d['offer'] != null) {
          tempSub?.cancel();
          final oMap = d['offer'];
          final offer = RTCSessionDescription(oMap['sdp'], oMap['type']);
          try {
            await webrtc.handleRemoteOffer(offer);
            _listenRemoteCandidates(FirestoreService.callerCandidates(callId));
            completer.complete();
          } catch (e) {
            completer.completeError(e);
          }
        }
      });

      // Wait up to 10 seconds for caller to initialize camera/offer
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          tempSub?.cancel();
          throw TimeoutException('Timed out waiting for caller to initialize connection');
        },
      );
    }
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
    _answerApplied = false;
  }

  // ─────────────────────────────────────────────
  // INTERNAL LISTENERS
  // ─────────────────────────────────────────────

  /// Caller listens for the answer SDP appearing on the call doc.
  /// Guard: _answerApplied ensures handleRemoteAnswer is called only once,
  /// even if the Firestore snapshot fires multiple times (e.g. when other
  /// fields on the doc are updated after the answer is written).
  void _listenForAnswer(DocumentReference<Map<String, dynamic>> docRef) {
    _callDocSub = docRef.snapshots().listen((snap) async {
      if (_answerApplied) return; // already processed — ignore re-fires

      final data = snap.data();
      if (data == null) return;

      final answerMap = data['answer'];
      if (answerMap != null) {
        _answerApplied = true; // set BEFORE async call to be race-safe
        debugPrint('[Signaling] Received answer SDP — applying to peer connection');
        try {
          final answer = RTCSessionDescription(answerMap['sdp'], answerMap['type']);
          await webrtc.handleRemoteAnswer(answer);
        } catch (e) {
          debugPrint('[Signaling] handleRemoteAnswer error: $e');
          _answerApplied = false; // allow retry on transient error
        }
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