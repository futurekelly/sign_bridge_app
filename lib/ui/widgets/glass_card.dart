// GlassCard — reusable glassmorphic container widget.
// Automatically adapts to light/dark theme.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/spacing.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = AppRadius.lg,
    this.blur = 12,
    this.opacity = 0.15,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: isLight
                  ? Colors.white.withValues(alpha: opacity)
                  : Colors.white.withValues(alpha: opacity * 0.35),
              border: Border.all(
                color: Colors.white.withValues(alpha: isLight ? 0.25 : 0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
