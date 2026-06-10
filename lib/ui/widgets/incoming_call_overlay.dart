import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../services/accessibility/vibration_service.dart';

class IncomingCallOverlay {
  static OverlayEntry? _entry;

  /// Shows the incoming call overlay on top of the current screen.
  static void show({
    required String callId,
    required String callerId,
    required String callerName,
    required String callerRole,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    if (_entry != null) return;

    final overlayState = AppRoutes.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _entry = OverlayEntry(
      builder: (context) => _IncomingCallOverlayWidget(
        callerName: callerName,
        callerRole: callerRole,
        onAccept: () {
          dismiss();
          onAccept();
        },
        onDecline: () {
          dismiss();
          onDecline();
        },
      ),
    );

    overlayState.insert(_entry!);
  }

  /// Dismisses the incoming call overlay.
  static void dismiss() {
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;
    VibrationService.instance.stopVibration();
  }
}

class _IncomingCallOverlayWidget extends StatefulWidget {
  final String callerName;
  final String callerRole;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallOverlayWidget({
    required this.callerName,
    required this.callerRole,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_IncomingCallOverlayWidget> createState() => _IncomingCallOverlayWidgetState();
}

class _IncomingCallOverlayWidgetState extends State<_IncomingCallOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Trigger deaf vibration alert pattern on startup
    VibrationService.instance.startIncomingCallVibration();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Ensure vibration loops are immediately cut off when screen closes
    VibrationService.instance.stopVibration();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Call Status Label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.phone_callback,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'INCOMING CALL',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Caller Avatar Placeholder
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Caller Details
                    Text(
                      widget.callerName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${widget.callerRole.toUpperCase()}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline Button
                        _buildCallButton(
                          onPressed: widget.onDecline,
                          icon: Icons.call_end,
                          color: AppColors.error,
                          label: 'Decline',
                        ),
                        // Accept Button
                        _buildCallButton(
                          onPressed: widget.onAccept,
                          icon: Icons.phone,
                          color: AppColors.success,
                          label: 'Answer',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            elevation: 8,
            shadowColor: color.withValues(alpha: 0.4),
          ),
          onPressed: onPressed,
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
