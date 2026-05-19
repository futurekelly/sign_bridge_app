// NeumorphicContainer — soft-shadow container that adapts to theme.
// Use for cards, buttons, and interactive surfaces.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';

class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final bool isPressed;
  final Color? color;
  final VoidCallback? onTap;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.radius = AppRadius.lg,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.isPressed = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = AppTheme.neumorphic(
      context,
      radius: radius,
      isPressed: isPressed,
      color: color,
    );

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }
    return container;
  }
}
