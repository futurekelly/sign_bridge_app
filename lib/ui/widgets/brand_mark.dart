// BrandMark — the SignBridge logo drawn in code.
//
// This exists so the mark cannot drift from the launcher icon again. Before
// this widget the login and profile-setup screens each carried their own
// hand-written Container with the *old* blue-on-blue gradient
// (primary -> primaryLight), while the launcher icon introduced in aab44cc
// uses primary -> secondary (blue -> emerald). The same logo therefore looked
// like two different logos depending on whether you were looking at the home
// screen or inside the app.
//
// The gradient below is the single source of truth for the in-app mark. It is
// deliberately the same pair of colours that tools/generate_brand_icon.py
// bakes into assets/branding/icon_*.png — if you change one, change both.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class BrandMark extends StatelessWidget {
  /// Edge length of the square the mark occupies.
  final double size;

  /// Glyph drawn on the mark. Defaults to the app's sign-language glyph, which
  /// is the same codepoint the launcher icon is generated from.
  final IconData icon;

  /// Blue (deaf) -> emerald (hearing). The whole point of the app is the
  /// meeting of those two, so the mark is a gradient between them rather than
  /// a single brand colour.
  static const List<Color> gradient = [AppColors.primary, AppColors.secondary];

  const BrandMark({
    super.key,
    this.size = 80,
    this.icon = Icons.sign_language,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );
  }
}
