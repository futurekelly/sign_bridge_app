// CaptionOverlay — real-time subtitle bar shown during calls.
// Visible for Deaf and Both roles. Fades after 8 seconds of silence.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/enums.dart';
import '../../core/spacing.dart';
import '../../core/utils/accessibility.dart';
import '../../data/models/translation_message.dart';
import '../widgets/glass_card.dart';

class CaptionOverlay extends StatefulWidget {
  final Stream<TranslationMessage> liveStream;
  final UserRole userRole;
  final double fontSize;
  final bool enabled;

  const CaptionOverlay({
    super.key,
    required this.liveStream,
    required this.userRole,
    this.fontSize = 16,
    this.enabled = true,
  });

  @override
  State<CaptionOverlay> createState() => _CaptionOverlayState();
}

class _CaptionOverlayState extends State<CaptionOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  String _text = '';
  String _source = '';
  bool _visible = false;
  Timer? _hideTimer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _sub = widget.liveStream.listen(_onMessage);
  }

  void _onMessage(TranslationMessage msg) {
    if (!widget.enabled) return;

    String displayText = msg.text.replaceAll('_', ' ');
    final gifKey = msg.gifKey;

    // Use emoji mapping for the 5 demo words if gifKey matches
    if (gifKey != null) {
      final emoji = _getEmojiForGifKey(gifKey);
      if (emoji != null) {
        // Format: [Emoji] \n [Text] \n [Swahili translation if applicable]
        final swahili = _getSwahiliForGifKey(gifKey);
        if (swahili != null) {
          displayText = "$emoji\n$displayText\n$swahili";
        } else {
          displayText = "$emoji\n$displayText";
        }
      }
    }

    setState(() {
      _text = displayText;
      _source = msg.source;
      _visible = true;
    });
    _animCtrl.forward();

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      _animCtrl.reverse().then((_) {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  String? _getEmojiForGifKey(String key) {
    return switch (key) {
      'hello'     => '👋',
      'yes'       => '👍',
      'no'        => '✋',
      'help'      => '🆘',
      'thank_you' => '🙏',
      _           => null,
    };
  }

  String? _getSwahiliForGifKey(String key) {
    return switch (key) {
      'hello'     => 'Habari',
      'yes'       => 'Ndiyo',
      'no'        => 'Hapana',
      'help'      => 'Msaada',
      'thank_you' => 'Asante',
      _           => null,
    };
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
    if (!AccessibilityHelper.shouldShowCaptions(widget.userRole) &&
        !widget.enabled) {
      return const SizedBox.shrink();
    }
    if (!_visible || _text.isEmpty) return const SizedBox.shrink();

    final isGesture = _source == 'gesture';

    return Positioned(
      bottom: 100,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GlassCard(
          blur: 16,
          opacity: 0.25,
          radius: AppRadius.xl,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Source icon
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (isGesture
                          ? Colors.blue
                          : Colors.green)
                      .withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGesture ? Icons.sign_language : Icons.mic,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Caption text
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
