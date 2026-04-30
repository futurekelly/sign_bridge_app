// CallModel — the Firestore document shape used for signaling.
//
// Firestore structure:
//   calls/{callId}
//     ├─ offer:  { sdp, type }
//     ├─ answer: { sdp, type }
//     ├─ callerId, calleeId
//     ├─ status: "waiting" | "active" | "ended"
//     └─ subcollections:
//          callerCandidates/{auto}   ← ICE from caller
//          calleeCandidates/{auto}   ← ICE from callee

class CallModel {
  final String callId;
  final String callerId;
  final String? calleeId;
  final String status;

  CallModel({
    required this.callId,
    required this.callerId,
    this.calleeId,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'callerId': callerId,
        'calleeId': calleeId,
        'status': status,
      };

  factory CallModel.fromMap(String id, Map<String, dynamic> map) => CallModel(
        callId: id,
        callerId: map['callerId'] ?? '',
        calleeId: map['calleeId'],
        status: map['status'] ?? 'waiting',
      );
}