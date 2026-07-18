// TranslationOverlay
// ─────────────────────────────────────────────────────────────
// Unified single-card translation display for both Deaf and Hearing users.
// Replaces the old GifOverlay + CaptionOverlay pair that produced
// duplicate information at overlapping screen positions.
//
// Behaviour:
//   • New message → replace immediately (no stacking)
//   • Auto-fades after 4 seconds
//   • Fades immediately when clearStream fires (gesture ended)
//   • Shows: source chip (🤟 gesture / 🎤 speech)
//            large emoji (52 px)
//            English word (bold 22 px)
//            Swahili word (light 15 px)

import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/translation_message.dart';
import '../../services/ai/inference_manager.dart';

class TranslationOverlay extends StatefulWidget {
  final Stream<TranslationMessage> liveStream;
  final Stream<void>? clearStream;

  const TranslationOverlay({
    super.key,
    required this.liveStream,
    this.clearStream,
  });

  @override
  State<TranslationOverlay> createState() => _TranslationOverlayState();
}

class _TranslationOverlayState extends State<TranslationOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<TranslationMessage>? _msgSub;
  StreamSubscription<void>? _clearSub;

  String _emoji  = '';
  String _enText = '';
  String _swText = '';
  String _source = '';
  bool   _visible = false;
  Timer? _hideTimer;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _scaleAnim;

  // ── Vocabulary maps ──────────────────────────────────────────
  // Full emoji mapping for all known gesture labels (keeps room to replace with GIF keys later)
  static const Map<String, String> _gestureEmoji = {
    'hello':     '👋',
    'yes':       '👍',
    'no':        '👎',
    'help':      '🆘',
    'book':      '📖',
    'car':       '🚗',
    'bus':       '🚌',
    'phone':     '📱',
    'drink':     '🥤',
    'water':     '💧',
    'eat':       '🍽️',
    'food':      '🍛',
    'fire':      '🔥',
    'school':    '🏫',
    'teacher':   '👨‍🏫',
    'student':   '🎓',
    'hospital':  '🏥',
    'doctor':    '👨‍⚕️',
    'medicine':  '💊',
    'police':    '👮',
    'work':      '💼',
    'shop':      '🛒',
    'money':     '💰',
    'home':      '🏠',
    'safe':      '🛡️',
    'danger':    '⚠️',
    'sleep':     '🛌',
    'walk':      '🚶',
    'run':       '🏃',
    'stop':      '✋',
    'sit':       '🪑',
    'stand':     '🧍',
    'mother':    '👩',
    'father':    '👨',
    'baby':      '👶',
    'boy':       '👦',
    'girl':      '👧',
    'child':     '🧒',
    'woman':     '👩',
    'man':       '👨',
    'friend':    '🤝',
    'come':      '👈',
    'go':        '👉',
    'computer':  '💻',
    'bread':     '🍞',
    'sorry':     '🙏',
    'please':    '🙏',
    'thank_you': '🙏',
  };

  static const Map<String, String> _speechEmoji = {
    'hello':     '👋',
    'yes':       '👍',
    'no':        '✋',
    'help':      '🆘',
    'thank_you': '🙏',
  };

  static const Map<String, List<String>> _bilingual = {
    'hello':     ['Hello',     'Habari'],
    'yes':       ['Yes',       'Ndiyo'],
    'no':        ['No',        'Hapana'],
    'help':      ['Help',      'Msaada'],
    'thank_you': ['Thank You', 'Asante'],
  };

  // Normalize any variant text → canonical key
  static const Map<String, String> _keyMap = {
    'hello':     'hello',     'habari':    'hello',     'hi':        'hello',
    'hujambo':   'hello',
    'yes':       'yes',       'ndiyo':     'yes',
    'no':        'no',        'hapana':    'no',
    'help':      'help',      'msaada':    'help',
    'thank you': 'thank_you', 'thank_you': 'thank_you', 'asante':    'thank_you',
    'thanks':    'thank_you',
  };

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );

    _msgSub   = widget.liveStream.listen(_onMessage);
    _clearSub = widget.clearStream?.listen((_) => _dismiss());
  }

  // Resolve gifKey or raw text → canonical vocabulary key
  String? _resolveKey(TranslationMessage msg) {
    // gifKey is the most reliable — already normalised by GestureMapperService
    if (msg.gifKey != null && msg.gifKey!.isNotEmpty) return msg.gifKey;

    // Normalize text: strip leading 'gesture.' if present, underscores -> spaces
    var lower = msg.text.toLowerCase().trim();
    if (lower.startsWith('gesture.')) lower = lower.substring(8);
    lower = lower.replaceAll('_', ' ').trim();

    if (_keyMap.containsKey(lower)) return _keyMap[lower];

    // Substring scan (handles "thank you" inside longer STT phrases)
    for (final entry in _keyMap.entries) {
      if (lower.contains(entry.key)) return _keyMap[entry.key]!;
    }
    return null;
  }

  void _onMessage(TranslationMessage msg) {
    final key = _resolveKey(msg);
    if (key == null) return; // unrecognised word — stay hidden

    final isGesture = msg.source == 'gesture';
    final emoji     = isGesture ? (_gestureEmoji[key] ?? '🤟') : (_speechEmoji[key] ?? '🎤');
    final bilingual = _bilingual[key] ?? [msg.text.replaceAll('_', ' '), ''];

    // Get confidence from InferenceManager if it's a gesture
    double confidence = 0.0;
    try {
      final inference = InferenceManager();
      if (isGesture && inference.prediction == key) {
        confidence = inference.confidence;
      }
    } catch (_) {}

    setState(() {
      _emoji   = emoji;
      _enText  = bilingual[0];
      _swText  = bilingual.length > 1 ? bilingual[1] : '';
      _source  = msg.source;
      _visible = true;
      _conf    = confidence;
    });

    _animCtrl.forward(from: 0.0);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  double _conf = 0.0;

  void _dismiss() {
    _animCtrl.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _clearSub?.cancel();
    _hideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _emoji.isEmpty) return const SizedBox.shrink();

    final isGesture  = _source == 'gesture';
    final accentColor = isGesture
        ? const Color(0xFF3B82F6)  // blue  for gesture
        : const Color(0xFF10B981); // green for speech

    return Positioned(
      bottom: 220,
      left:   20,
      right:  20,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:       accentColor.withValues(alpha: 0.28),
                  blurRadius:  22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize:    MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Source chip (gesture 🤟 / speech 🎤)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:        accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isGesture ? Icons.sign_language_rounded : Icons.mic_rounded,
                    color: accentColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 14),
                // Large emoji
                Text(_emoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(width: 14),
                // English + Swahili
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _enText,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   22,
                          fontWeight: FontWeight.bold,
                          height:     1.1,
                        ),
                      ),
                      if (_swText.isNotEmpty)
                        Text(
                          _swText,
                          style: TextStyle(
                            color:      Colors.white.withValues(alpha: 0.65),
                            fontSize:   15,
                            fontWeight: FontWeight.w400,
                            height:     1.2,
                          ),
                        ),
                      if (_source == 'gesture' && _conf > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Confidence: ${(_conf * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _conf > 0.8 ? Colors.greenAccent : Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
