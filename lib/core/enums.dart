// Central enum definitions used across all layers.
// Defined here to prevent string typos and keep contracts consistent.

/// Source of an AI-generated translation result.
enum TranslationSource { gesture, speech }

/// Direction of communication flow.
enum TranslationDirection { deafToHearing, hearingToDeaf }

/// Status of the AI subsystem (shown by ai_status_overlay).
enum AiStatus {
  idle,
  listening,        // SpeechService active
  recognizing,      // GestureRecognitionService active
  processing,       // generic processing state
  error,
}

/// User accessibility role — determines which UI features are shown.
enum UserRole {
  deaf,     // Prioritize visual: GIF panel, captions, visual alerts
  hearing,  // Prioritize audio: mic/speaker controls, optional captions
  both,     // Full feature set: all translation + accessibility features
}

/// Caller vs callee in a WebRTC call.
enum CallRole { caller, callee }

/// Route arguments for CallScreen.
class CallArgs {
  final CallRole role;
  final String callId;
  final String peerUid;
  const CallArgs({
    required this.role,
    this.callId = '',
    this.peerUid = '',
  });
}

/// Helpers to (de)serialize for DataChannel JSON payloads.
extension TranslationSourceX on TranslationSource {
  String get value => name; // "gesture" or "speech"
  static TranslationSource fromString(String s) =>
      TranslationSource.values.firstWhere((e) => e.name == s);
}

/// Helper to serialize UserRole for Hive / JSON.
extension UserRoleX on UserRole {
  String get value => name;
  static UserRole fromString(String s) =>
      UserRole.values.firstWhere((e) => e.name == s, orElse: () => UserRole.both);
}