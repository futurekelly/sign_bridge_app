// GifOverlay — animated GIF translation panel shown during calls.
// Visible for Deaf and Both roles. Auto-hides after 5 seconds.

import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/spacing.dart';
import '../../core/enums.dart';
import '../../core/utils/accessibility.dart';
import '../../data/models/translation_message.dart';
import '../../services/ai/gesture_mapper_service.dart';
import '../widgets/glass_card.dart';

class GifOverlay extends StatefulWidget {
  final Stream<TranslationMessage> liveStream;
  final UserRole userRole;

  const GifOverlay({
    super.key,
    required this.liveStream,
    required this.userRole,
  });

  @override
  State<GifOverlay> createState() => _GifOverlayState();
}

class _GifOverlayState extends State<GifOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  String? _currentGifKey;
  String _currentText = '';
  bool _visible = false;
  Timer? _hideTimer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);

    _sub = widget.liveStream.listen(_onMessage);
  }

  void _onMessage(TranslationMessage msg) {
    final gifKey = msg.gifKey ?? GestureMapperService.mapTextToGifKey(msg.text);
    if (gifKey == null) return;

    setState(() {
      _currentGifKey = gifKey;
      _currentText = msg.text.replaceAll('_', ' ');
      _visible = true;
    });
    _animCtrl.forward();

    // Auto-hide after 3 seconds.
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      _animCtrl.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AccessibilityHelper.shouldShowGifPanel(widget.userRole)) {
      return const SizedBox.shrink();
    }
    if (!_visible || _currentGifKey == null) return const SizedBox.shrink();

    final scale = AccessibilityHelper.gifScale(widget.userRole);
    final size = 120.0 * scale;
    final assetPath = GestureMapperService.assetPathForKey(_currentGifKey);

    return Positioned(
      bottom: 140,
      left: AppSpacing.md,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GlassCard(
          blur: 14,
          opacity: 0.2,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GIF display
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: Colors.black.withValues(alpha: 0.15),
                ),
                clipBehavior: Clip.antiAlias,
                child: assetPath != null
                    ? Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Label
              Text(
                _currentText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sign_language,
                      size: 12, color: Colors.white.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    'Sign Language',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sign_language,
              size: 32, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Text(
            'Sign',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
