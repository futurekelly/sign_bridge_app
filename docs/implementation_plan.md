# Final Approved Implementation Plan: Phase 1 Signaling & SignBridge IDs

This plan implements username registration uniqueness locks and direct calling mechanisms via atomic transactions in Firestore.

---

## 1. Updated Firestore Schema

### `/usernames/{lowercase_id}` (Document)
- **ID:** Lowercase SignBridge ID (e.g. `kelvin`).
- **Data:**
  ```json
  {
    "uid": "firebase_auth_user_uid"
  }
  ```

### `/users/{uid}` (Document)
- **ID:** Firebase Auth UID.
- **Data:**
  ```json
  {
    "uid": "firebase_auth_user_uid",
    "displayName": "Kelvin Mbise",
    "signBridgeId": "kelvin",
    "status": "idle",
    "createdAt": "serverTimestamp"
  }
  ```

### `/calls/{callId}` (Document)
- **ID:** Auto-generated Firestore ID.
- **Data:**
  ```json
  {
    "callerId": "caller_uid",
    "calleeId": "callee_uid",
    "status": "dialing",
    "offer": {
      "sdp": "...",
      "type": "offer"
    },
    "answer": {
      "sdp": "...",
      "type": "answer"
    },
    "timestamp": "serverTimestamp"
  }
  ```
- **Sub-collections:**
  - `/calls/{callId}/callerCandidates` (ICE Candidates)
  - `/calls/{callId}/calleeCandidates` (ICE Candidates)

---

## 2. Transaction Flowcharts

### A. Registration Uniqueness Transaction
```mermaid
sequenceDiagram
    autonumber
    actor App as Client Registration
    participant DB as Firestore Transaction
    App->>DB: Start Transaction
    DB->>DB: Read /usernames/{lowercase_id}
    alt Exists
        DB-->>App: Abort (Username already taken)
    else Available
        DB->>DB: Write /usernames/{lowercase_id} = {"uid": uid}
        DB->>DB: Write /users/{uid} = profile details + status: 'idle'
        DB-->>App: Commit Transaction Success
    end
```

### B. Call Dialing Lock Transaction
```mermaid
sequenceDiagram
    autonumber
    actor Caller as Caller Client
    participant DB as Firestore Transaction
    Caller->>DB: Start Transaction
    DB->>DB: Read /users/{calleeUid}
    alt callee status is not 'idle'
        DB-->>Caller: Abort (User Busy)
    else callee status is 'idle'
        DB->>DB: Set /users/{calleeUid}/status = 'busy'
        DB->>DB: Set /users/{callerUid}/status = 'busy'
        DB->>DB: Write /calls/{callId} = {'callerId': callerUid, 'calleeId': calleeUid, 'status': 'dialing'}
        DB-->>Caller: Commit Transaction Success
    end
```

---

## 3. Scope of File Modifications

### Modifications:
* **`lib/services/firebase/firestore_service.dart`**: Adds accessor helper functions for usernames and call logs.
* **`lib/services/auth/auth_service.dart`**: Implements the registration transaction.
* **`lib/ui/screens/login_screen.dart`**: Inputs username fields and sanitization patterns.
* **`lib/services/webrtc/signaling_service.dart`**: Accepts dynamic `callId` configurations.
* **`lib/controllers/call_controller.dart`**: Manages dials and dispatches.

### New Service:
* **`lib/services/webrtc/call_manager.dart`**: Orchestrates dialing locks, timers, and active status updates.
