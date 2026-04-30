// Centralized constants. Avoid magic strings scattered across codebase.

class AppConstants {
  static const String appName = 'SignBridge';
  static const String appTagline = 'Connecting Voices and Signs';

  // Default supported languages (per architecture spec).
  static const List<String> supportedLanguages = ['en', 'sw'];

  // Default values
  static const String defaultLanguage = 'en';
}