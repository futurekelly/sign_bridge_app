// RoleBadge — small colored badge showing user accessibility role.

import 'package:flutter/material.dart';
import '../../core/enums.dart';
import '../../core/spacing.dart';

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool compact;

  const RoleBadge({super.key, required this.role, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _roleData();
    if (compact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  (String, Color, IconData) _roleData() {
    switch (role) {
      case UserRole.deaf:
        return ('Deaf', const Color(0xFF2563EB), Icons.sign_language);
      case UserRole.hearing:
        return ('Hearing', const Color(0xFF10B981), Icons.hearing);
      case UserRole.both:
        return ('Both', const Color(0xFF8B5CF6), Icons.accessibility_new);
    }
  }
}
