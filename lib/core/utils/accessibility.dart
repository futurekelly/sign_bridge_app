// Role-based accessibility helpers.
// Every UI decision based on UserRole should flow through this class
// so behaviour is consistent and easy to audit in one place.

import '../enums.dart';

class AccessibilityHelper {
  const AccessibilityHelper._();

  // ── Feature visibility ──

  /// Animated GIF translation panel (sign language visuals).
  static bool shouldShowGifPanel(UserRole role) =>
      role == UserRole.deaf;

  /// Real-time captions / subtitles overlay.
  static bool shouldShowCaptions(UserRole role) =>
      role == UserRole.deaf || role == UserRole.both;

  /// Text-to-Speech playback of recognised gestures.
  static bool shouldEnableTTS(UserRole role) =>
      role == UserRole.hearing || role == UserRole.both;

  /// Microphone / speaker controls prominence.
  static bool shouldShowMicControls(UserRole role) =>
      role == UserRole.hearing || role == UserRole.both;

  /// Use haptic / visual alerts instead of audio.
  static bool useVisualNotifications(UserRole role) =>
      role == UserRole.deaf || role == UserRole.both;

  // ── Scaling ──

  /// Font scale multiplier — larger for deaf users who rely on text.
  static double fontScale(UserRole role) =>
      role == UserRole.deaf ? 1.2 : 1.0;

  /// GIF overlay size multiplier.
  static double gifScale(UserRole role) =>
      role == UserRole.deaf ? 1.3 : 1.0;

  // ── Defaults ──

  /// Whether the mic should start muted by default.
  static bool defaultMicMuted(UserRole role) =>
      role == UserRole.deaf;

  /// Descriptive label for the role (used in badges / settings).
  static String roleLabel(UserRole role) {
    switch (role) {
      case UserRole.deaf:    return 'Deaf User';
      case UserRole.hearing: return 'Hearing User';
      case UserRole.both:    return 'Both';
    }
  }

  /// Icon name suggestion per role (Material icon names).
  static String roleIconName(UserRole role) {
    switch (role) {
      case UserRole.deaf:    return 'sign_language';
      case UserRole.hearing: return 'hearing';
      case UserRole.both:    return 'accessibility_new';
    }
  }
}
