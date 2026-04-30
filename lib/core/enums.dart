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

/// Helpers to (de)serialize for DataChannel JSON payloads.
extension TranslationSourceX on TranslationSource {
  String get value => name; // "gesture" or "speech"
  static TranslationSource fromString(String s) =>
      TranslationSource.values.firstWhere((e) => e.name == s);
}