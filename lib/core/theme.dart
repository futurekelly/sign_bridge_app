// Single source of truth for visual styling.
// Provides light + dark themes, neumorphic helpers, and glassmorphic decorations.

import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// CENTRALISED COLORS
// ─────────────────────────────────────────────────────────────

class AppColors {
  const AppColors._();

  // Brand
  static const Color primary       = Color(0xFF2563EB); // blue-600
  static const Color primaryLight  = Color(0xFF60A5FA); // blue-400
  static const Color primaryDark   = Color(0xFF1D4ED8); // blue-700
  static const Color secondary     = Color(0xFF10B981); // emerald-500
  static const Color accent        = Color(0xFF8B5CF6); // violet-500

  // Light palette
  static const Color lightBg       = Color(0xFFF0F4F8);
  static const Color lightSurface  = Color(0xFFFFFFFF);
  static const Color lightCard     = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextMuted   = Color(0xFF64748B);
  static const Color lightDivider     = Color(0xFFE2E8F0);

  // Dark palette
  static const Color darkBg        = Color(0xFF0F172A);
  static const Color darkSurface   = Color(0xFF1E293B);
  static const Color darkCard      = Color(0xFF1E293B);
  static const Color darkTextPrimary  = Color(0xFFF1F5F9);
  static const Color darkTextMuted    = Color(0xFF94A3B8);
  static const Color darkDivider      = Color(0xFF334155);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);
}

// ─────────────────────────────────────────────────────────────
// THEME DATA
// ─────────────────────────────────────────────────────────────

class AppTheme {
  // Legacy accessors (kept for backward compat while migrating screens).
  static const Color primary   = AppColors.primary;
  static const Color secondary = AppColors.secondary;
  static const Color background = AppColors.lightBg;
  static const Color surface   = AppColors.lightSurface;
  static const Color textDark  = AppColors.lightTextPrimary;
  static const Color textMuted = AppColors.lightTextMuted;

  // ── Light Theme ──
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  // ── Dark Theme ──
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    final bg      = isLight ? AppColors.lightBg      : AppColors.darkBg;
    final surf    = isLight ? AppColors.lightSurface  : AppColors.darkSurface;
    final card    = isLight ? AppColors.lightCard     : AppColors.darkCard;
    final textP   = isLight ? AppColors.lightTextPrimary : AppColors.darkTextPrimary;
    final textM   = isLight ? AppColors.lightTextMuted   : AppColors.darkTextMuted;
    final divider = isLight ? AppColors.lightDivider     : AppColors.darkDivider;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: surf,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      dividerColor: divider,
      cardColor: card,

      appBarTheme: AppBarTheme(
        backgroundColor: surf,
        foregroundColor: textP,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? Colors.white
            : AppColors.darkSurface.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surf,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textM,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: textP,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
        headlineMedium: TextStyle(
          color: textP,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleLarge: TextStyle(
          color: textP,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: textP,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(color: textP, fontSize: 16),
        bodyMedium: TextStyle(color: textP, fontSize: 14),
        bodySmall: TextStyle(color: textM, fontSize: 12),
        labelLarge: TextStyle(
          color: textP,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NEUMORPHIC HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Soft neumorphic box decoration for light mode.
  static BoxDecoration neumorphicLight({
    Color color = AppColors.lightBg,
    double radius = 16,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.7),
                offset: const Offset(-1, -1),
                blurRadius: 4,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(4, 4),
                blurRadius: 12,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                offset: const Offset(-4, -4),
                blurRadius: 12,
              ),
            ],
    );
  }

  /// Soft neumorphic box decoration for dark mode.
  static BoxDecoration neumorphicDark({
    Color color = AppColors.darkSurface,
    double radius = 16,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.03),
                offset: const Offset(-1, -1),
                blurRadius: 4,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(4, 4),
                blurRadius: 12,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                offset: const Offset(-4, -4),
                blurRadius: 12,
              ),
            ],
    );
  }

  /// Returns the appropriate neumorphic decoration based on brightness.
  static BoxDecoration neumorphic(
    BuildContext context, {
    double radius = 16,
    bool isPressed = false,
    Color? color,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return isLight
        ? neumorphicLight(
            color: color ?? AppColors.lightBg, radius: radius, isPressed: isPressed)
        : neumorphicDark(
            color: color ?? AppColors.darkSurface, radius: radius, isPressed: isPressed);
  }

  // ─────────────────────────────────────────────────────────────
  // GLASSMORPHIC HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Glassmorphic box decoration — frosted glass effect.
  static BoxDecoration glassMorphic(
    BuildContext context, {
    double radius = 16,
    double opacity = 0.15,
    double borderOpacity = 0.2,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: isLight
          ? Colors.white.withValues(alpha: opacity)
          : Colors.white.withValues(alpha: opacity * 0.4),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: 1,
      ),
    );
  }

  /// A ClipRRect + BackdropFilter wrapper for glassmorphic effect.
  /// Use as a parent widget: `AppTheme.glassContainer(context, child: ...)`
  static Widget glassContainer(
    BuildContext context, {
    required Widget child,
    double radius = 16,
    double blur = 12,
    double opacity = 0.15,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: glassMorphic(context, radius: radius, opacity: opacity),
          child: child,
        ),
      ),
    );
  }
}