// TranslationController
// ════════════════════════════════════════════════════════════════════
// ⭐ THE ONLY PLACE THAT TALKS TO AI SERVICES. ⭐
//
// Responsibilities:
//   1. Subscribes to PredictionStabilizer.stablePredictionStream + SpeechService streams
//   2. Enriches results with gifKey via GestureMapperService
//   3. Speaks gesture results via TTSService (Deaf → Hearing)
//   4. Persists every result to HistoryRepository
//   5. Exposes 3 streams to the UI:
//        • liveResultStream  → transient (caption + gif overlays)
//        • historyStream     → cumulative (translation_panel)
//        • statusStream      → AiStatus (ai_status_overlay)
//   6. Accepts incoming peer messages from DataChannel and forwards local messages
//
// CONTRACT (enforced):
//   - UI widgets NEVER import or instantiate AI services directly.
//   - UI widgets ONLY listen to the 3 streams above.
//   - Outbound DataChannel sending happens through `onOutgoing` callback.
// ════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/enums.dart';
import '../core/translations.dart';
import '../data/models/translation_message.dart';
import '../data/repositories/history_repository.dart';
import '../services/ai/gesture_recognition_service.dart';
import '../services/ai/gesture_mapper_service.dart';
import '../services/ai/speech_service.dart';
import '../services/ai/tts_service.dart';
import '../services/ai/inference_manager.dart';

class TranslationController extends ChangeNotifier {
  // ── Injected services (kept private — UI must not access them) ──
  final GestureRecognitionService _gesture;
  final SpeechService _speech;
  final TTSService _tts;
  final HistoryRepository _history;

  // ── Outbound hook (set by CallController) ──
  /// Called whenever a LOCAL result is produced.
  /// Wired to WebRTCService.sendDataChannelMessage(json).
  void Function(String jsonPayload)? onOutgoing;

  // ── Public streams (the contract with UI) ──
  final _liveCtrl = StreamController<TranslationMessage>.broadcast();
  final _historyCtrl = StreamController<List<TranslationMessage>>.broadcast();
  final _statusCtrl = StreamController<AiStatus>.broadcast();

  /// LIVE — single latest result. TranslationOverlay subscribes.
  Stream<TranslationMessage> get liveResultStream => _liveCtrl.stream;

  /// HISTORY — full conversation log. translation_panel subscribes.
  Stream<List<TranslationMessage>> get historyStream => _historyCtrl.stream;

  /// STATUS — system state. ai_status_overlay subscribes.
  Stream<AiStatus> get statusStream => _statusCtrl.stream;

  /// CLEAR — fires when the hand is removed (gesture ended).
  /// TranslationOverlay listens to this to immediately dismiss the card.
  Stream<void> get clearStream => _clearCtrl.stream;

  /// Exposes InferenceManager for UI access to performance stats and hand landmarks
  InferenceManager get inferenceManager => _gesture.inferenceManager;

  // ── Internal state ──
  final List<TranslationMessage> _historyCache = [];
  final List<StreamSubscription> _subs = [];
  final _clearCtrl = StreamController<void>.broadcast();

  bool    _started       = false;
  String  _languageCode  = 'en';
  bool    _ttsEnabled    = true;
  AiStatus _currentStatus = AiStatus.idle;
  String  get languageTag => _languageCode;

  // Active-gesture guard: prevents repeated TTS when the same gesture is held.
  String?   _activeGestureLabel;
  DateTime? _activeGestureSince;

  // ─────────────────────────────────────────────
  // CONSTRUCTION
  // ─────────────────────────────────────────────

  TranslationController({
    GestureRecognitionService? gesture,
    SpeechService? speech,
    TTSService? tts,
    HistoryRepository? history,
  })  : _gesture = gesture ?? GestureRecognitionService(),
        _speech = speech ?? SpeechService(),
        _tts = tts ?? TTSService(),
        _history = history ?? HistoryRepository() {
    // Seed the history stream with whatever already exists locally.
    _historyCache.addAll(_history.getAll());
  }

  // ─────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────

  Future<void> start({
    String languageCode = 'en',
    MediaStreamTrack? localVideoTrack,
    bool ttsEnabled = true,
  }) async {
    if (_started) return;
    _started = true;
    _languageCode = languageCode;
    _ttsEnabled = ttsEnabled;

    // Determine locale codes based on language selection.
    final ttsLang = languageCode == 'sw' ? 'sw-TZ' : 'en-US';
    final sttLocale = languageCode == 'sw' ? 'sw_TZ' : 'en_US';

    // Initialize TTS with the correct language.
    await _tts.initialize(language: ttsLang);

    // Subscribe to PredictionStabilizer streams
    _subs.add(_gesture.inferenceManager.stabilizer.stablePredictionStream.listen(_onStablePrediction));
    _subs.add(_gesture.inferenceManager.stabilizer.gestureEndStream.listen((_) {
      // Hand removed → clear active label and notify overlay to dismiss.
      _activeGestureLabel = null;
      _activeGestureSince = null;
      if (!_clearCtrl.isClosed) _clearCtrl.add(null);
      debugPrint('[TranslationController] Gesture ended — overlay dismissed');
    }));

    _subs.add(_gesture.statusStream.listen(_emitStatus));

    _subs.add(_speech.resultStream.listen(_onSpeechResult));
    _subs.add(_speech.statusStream.listen(_emitStatus));

    // Initialize STT with the correct locale, then start both pipelines.
    await _speech.initialize(locale: sttLocale);
    await Future.wait([
      _gesture.start(localVideoTrack: localVideoTrack),
      _speech.start(),
    ]);

    // Emit current cached history so late subscribers see something.
    _historyCtrl.add(List.unmodifiable(_historyCache));
  }

  /// Stops the AI pipeline.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;

    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();

    await Future.wait([
      _gesture.stop(),
      _speech.stop(),
      _tts.stop(),
    ]);

    _emitStatus(AiStatus.idle);
  }

  // ─────────────────────────────────────────────
  // INCOMING (LOCAL AI)
  // ─────────────────────────────────────────────

  /// Handles stabilized predictions from PredictionStabilizer.
  /// Publishes locally, forwards to remote peer via DataChannel, and speaks via TTS if enabled.
  void _onStablePrediction(PredictionResult result) {
    // Guard: if simulateLocalGesture() already dispatched this word within 3 s,
    // skip re-emission to prevent a second TTS call from the stabilizer loop.
    if (result.label == _activeGestureLabel && _activeGestureSince != null) {
      if (DateTime.now().difference(_activeGestureSince!) < const Duration(seconds: 3)) {
        debugPrint('[TranslationController] Skip duplicate stabilizer emission for ${result.label}');
        return;
      }
    }

    final String rawLabel       = result.label;
    final String gifKey         = GestureMapperService.mapTextToGifKey(rawLabel) ?? rawLabel;
    final String translatedText = AppTranslations.t('gesture.$rawLabel', _languageCode);

    // Ensure displayed/spoken text is clean (no leading 'gesture.' prefix)
    final String cleanText = _cleanLabelText(translatedText);

    final msg = TranslationMessage(
      text:     cleanText,
      source:   'gesture',
      language: _languageCode,
      gifKey:   gifKey,
    );

    _activeGestureLabel = rawLabel;
    _activeGestureSince = DateTime.now();

    _publishLocal(msg);
    if (_ttsEnabled) {
      _tts.speak(cleanText);
    }
  }

  /// Local speech recognition → text + GIF lookup (no TTS, no echo).
  void _onSpeechResult(TranslationMessage raw) {
    final enriched = raw.copyWith(
      gifKey: GestureMapperService.mapTextToGifKey(raw.text),
    );
    _publishLocal(enriched);
  }

  // ─────────────────────────────────────────────
  // INCOMING (FROM PEER VIA DATACHANNEL)
  // ─────────────────────────────────────────────

  /// Called by CallController when a JSON payload arrives over WebRTC DataChannel.
  /// Funnels peer messages through the same pipeline for local UI display and TTS audio if enabled.
  void handleIncomingPeerJson(String jsonPayload) {
    try {
      final map = json.decode(jsonPayload) as Map<String, dynamic>;
      final msg = TranslationMessage.fromJson(map); // fromPeer = true

      // Re-validate gifKey on this side (assets may differ between builds).
      final String? effectiveGifKey = msg.gifKey ?? GestureMapperService.mapTextToGifKey(msg.text);

      // If it's a gesture, we re-translate it to the LOCAL language using the gifKey
      // so the TTS and Captions match the receiver's preference.
      TranslationMessage processed = msg.copyWith(gifKey: effectiveGifKey);

      if (msg.source == 'gesture' && effectiveGifKey != null) {
        final localText = AppTranslations.t('gesture.$effectiveGifKey', _languageCode);
        processed = TranslationMessage(
          id: msg.id,
          text: _cleanLabelText(localText),
          source: 'gesture',
          language: _languageCode,
          gifKey: effectiveGifKey,
          timestamp: msg.timestamp,
          fromPeer: true,
        );
      } else if (msg.source == 'gesture') {
        // No effective gifKey — sanitize whatever text we received
        processed = TranslationMessage(
          id: msg.id,
          text: _cleanLabelText(msg.text),
          source: 'gesture',
          language: _languageCode,
          gifKey: msg.gifKey,
          timestamp: msg.timestamp,
          fromPeer: true,
        );
      }

      _publishRemote(processed);

      // If the peer's gesture is being shown to us, speak it aloud via TTS if enabled
      if (processed.source == 'gesture') {
        if (_ttsEnabled) {
          _tts.speak(processed.text);
        }
      }
    } catch (e) {
      debugPrint('[TranslationController] bad peer payload: $e');
    }
  }

  // ─────────────────────────────────────────────
  // PUBLISHING (the only place that touches the 3 streams)
  // ─────────────────────────────────────────────

  void _publishLocal(TranslationMessage msg) {
    _emitMessage(msg);

    // Forward to peer (DataChannel) if the hook is wired.
    final outgoing = onOutgoing;
    if (outgoing != null) {
      // Send sanitized JSON (strip gesture. prefix in text for remote)
      final map = msg.toJson();
      var outgoingText = map['text'] as String? ?? '';
      if (outgoingText.toLowerCase().startsWith('gesture.')) outgoingText = outgoingText.substring(8);
      outgoingText = outgoingText.replaceAll('_', ' ').trim();
      map['text'] = outgoingText;
      outgoing(json.encode(map));
    }
  }

  void _publishRemote(TranslationMessage msg) {
    _emitMessage(msg);
    // No outgoing forwarding for remote-originated messages.
  }

  void _emitMessage(TranslationMessage msg) {
    // Ensure text is clean before persisting / emitting / forwarding
    final cleanText = _cleanLabelText(msg.text);

    final sanitized = TranslationMessage(
      id: msg.id,
      text: cleanText,
      source: msg.source,
      language: msg.language,
      gifKey: msg.gifKey,
      timestamp: msg.timestamp,
      fromPeer: msg.fromPeer,
    );

    // 1) Persist
    _history.save(sanitized);

    // 2) Update history cache + stream (cumulative)
    _historyCache.insert(0, sanitized); // newest first
    _historyCtrl.add(List.unmodifiable(_historyCache));

    // 3) Emit live (transient)
    _liveCtrl.add(sanitized);
  }

  void _emitStatus(AiStatus s) {
    if (s == _currentStatus) return;
    _currentStatus = s;
    _statusCtrl.add(s);
    notifyListeners();
  }

  /// Normalize labels for display and TTS: strip leading 'gesture.' and underscores,
  /// trim and capitalise for readability.
  String _cleanLabelText(String txt) {
    var t = txt.trim();
    if (t.toLowerCase().startsWith('gesture.')) {
      t = t.substring(8);
    }
    t = t.replaceAll('_', ' ').trim();
    if (t.isEmpty) return t;
    // Keep capitalization of translated strings intact, otherwise capitalise first char
    if (t == t.toLowerCase()) {
      t = t[0].toUpperCase() + (t.length > 1 ? t.substring(1) : '');
    }
    return t;
  }

  /// Simulates a local gesture result (toolbar tap injection hook).
  /// Sets the active-gesture guard so the stabilizer loop doesn't double-emit TTS.
  void simulateLocalGesture(String rawLabel) {
    _activeGestureLabel = rawLabel;
    _activeGestureSince = DateTime.now();

    final String gifKey         = GestureMapperService.mapTextToGifKey(rawLabel) ?? rawLabel;
    final String translatedText = AppTranslations.t('gesture.$rawLabel', _languageCode);
    final String cleanText      = _cleanLabelText(translatedText);

    final msg = TranslationMessage(
      text:     cleanText,
      source:   'gesture',
      language: _languageCode,
      gifKey:   gifKey,
    );

    _publishLocal(msg);
    if (_ttsEnabled) {
      _tts.speak(cleanText);
    }
  }

  /// Simulates a local speech result for testing (injection hook)
  void simulateLocalSpeech(String text) {
    final msg = TranslationMessage(
      text: text,
      source: 'speech',
      language: languageTag,
    );
    _onSpeechResult(msg);
  }

  // ─────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    await stop();
    await _gesture.dispose();
    await _speech.dispose();
    await _tts.dispose();
    await _liveCtrl.close();
    await _historyCtrl.close();
    await _statusCtrl.close();
    await _clearCtrl.close();
    super.dispose();
  }}
