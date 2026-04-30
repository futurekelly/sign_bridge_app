// Single source of truth for visual styling.
// Keeps UI consistent across all four screens.

import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors — calm, accessible palette suitable for inclusive UX.
  static const Color primary = Color(0xFF2563EB);   // blue-600
  static const Color secondary = Color(0xFF10B981); // emerald-500
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: secondary,
          background: background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textDark,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(color: textDark),
          bodySmall: TextStyle(color: textMuted),
        ),
      );
}