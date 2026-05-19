// Consistent spacing & radius tokens used across all screens.
// Eliminates ad-hoc padding values and keeps visual rhythm uniform.

class AppSpacing {
  const AppSpacing._();

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  /// Standard screen padding.
  static const double screenPadding = 24;
}

class AppRadius {
  const AppRadius._();

  static const double xs  = 6;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 28;
  static const double pill = 100;
}
