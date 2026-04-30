// FirestoreService
// ─────────────────────────────────────────────────────────────
// Centralized Firestore helpers. Keeping path strings here
// prevents typos across the codebase.
//
// IMPORTANT (architecture rule): this file is used ONLY for
// signaling documents. No translation messages. No AI data.

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Paths
  static CollectionReference<Map<String, dynamic>> get callsRef =>
      _db.collection('calls');

  static DocumentReference<Map<String, dynamic>> callDoc(String callId) =>
      callsRef.doc(callId);

  static CollectionReference<Map<String, dynamic>> callerCandidates(String callId) =>
      callDoc(callId).collection('callerCandidates');

  static CollectionReference<Map<String, dynamic>> calleeCandidates(String callId) =>
      callDoc(callId).collection('calleeCandidates');
}