// SpeechService
// ─────────────────────────────────────────────────────────────
// Real Speech-to-Text using the speech_to_text plugin.
// Emits the same TranslationMessage shape as GestureRecognitionService,
// keeping the AI pipeline uniform.
//
// ── Fix (Sep 2026) ──────────────────────────────────────────
// • ROOT CAUSE of "the hearing user speaks and nothing appears on
//   the deaf phone": the recognizer never produced a single word.
//   Logcat showed `error_speech_timeout, permanent: true` — that is
//   Android's ERROR_SPEECH_TIMEOUT, "no speech input". The mic was
//   being held by the WebRTC session in this same process. Fixed in
//   webrtc_service.dart by making the call video-only.
//
// • Belt and braces against that timeout: `listenFor` + `pauseFor`
//   make the plugin stop GRACEFULLY after a silence, before
//   Android's own recognizer timeout can fire. The old code set
//   `listenFor` alone, which still let the timeout through.
//
// • Permanent errors are now RECOVERED from. The old code re-armed
//   the recognizer without re-initializing it, so a `permanent: true`
//   error (exactly what the log showed) left STT dead for the rest
//   of the call.
//
// • Removed a dead `vocab` / `isMatch` block that was computed on
//   every result and never read.
//
// • Added microphone-level reporting. If the peak level stays at -2
//   while someone is talking, the mic is blocked — previously that
//   had to be guessed at; now it is visible in logcat.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/enums.dart';
import '../../data/models/translation_message.dart';

class SpeechService {
  final stt.SpeechToText _stt = stt.SpeechToText();

  final _resultCtrl = StreamController<TranslationMessage>.broadcast();
  final _statusCtrl = StreamController<AiStatus>.broadcast();

  Stream<TranslationMessage> get resultStream => _resultCtrl.stream;
  Stream<AiStatus> get statusStream => _statusCtrl.stream;

  bool _initialized = false;
  bool _listening = false;
  bool _wantRunning = false; // true while stop() hasn't been called
  bool _recovering = false;  // guards against overlapping recovery runs

  /// Locale: "en_US" by default. Pass "sw_TZ" for Swahili.
  String _locale = 'en_US';
  String get languageTag => _locale.split('_').first; // "en" / "sw"

  // ── Restart control ──
  Timer? _restartTimer;
  int _consecutiveErrors = 0;

  // ── Diagnostics ──
  double _peakLevel = -2.0;
  DateTime _lastLevelLog = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastEmitted = '';

  /// Stop after this long even without a silence — keeps the recognizer
  /// from running indefinitely and lets us recycle it.
  static const Duration _listenFor = Duration(seconds: 30);

  /// Stop after this long WITHOUT speech. This is the important one: it is
  /// shorter than Android's internal speech timeout, so the plugin ends the
  /// session cleanly instead of Android failing it with
  /// `error_speech_timeout` (which the plugin then reports as permanent).
  static const Duration _pauseFor = Duration(seconds: 5);

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  Future<bool> initialize({String locale = 'en_US'}) async {
    _locale = locale;
    if (_initialized) return true;

    try {
      debugPrint('[SpeechService] Initializing STT for locale: $locale');
      _initialized = await _stt.initialize(
        onStatus: (s) {
          debugPrint('[SpeechService] Plugin status: $s');
          _onPluginStatus(s);
        },
        onError: (e) {
          debugPrint('[SpeechService] SpeechToText error callback: $e '
              '(permanent: ${e.permanent})');
          _statusCtrl.add(AiStatus.error);
          _handleError(isPermanent: e.permanent);
        },
      );
      debugPrint('[SpeechService] Initialization result: $_initialized');
      if (_initialized) await _logAvailableLocales();
    } catch (e) {
      debugPrint('[SpeechService] Failed to initialize SpeechToText '
          '(not supported on this device?): $e');
      _initialized = false;
    }
    return _initialized;
  }

  /// Reports which speech locales this device actually supports.
  ///
  /// Android falls back to the system default when the requested locale has no model
  /// installed, and it does so silently — the recognizer simply transcribes with the
  /// wrong language and returns plausible-looking text. That is why Swahili speech
  /// ("habari", "asante") came back as English words: the app asked for en_US.
  /// Logging the list makes such a fallback visible rather than mysterious.
  Future<void> _logAvailableLocales() async {
    try {
      final locales = await _stt.locales();
      final tags = locales.map((l) => l.localeId).toList();
      debugPrint('[SpeechService] Device supports ${tags.length} locales: '
          '${tags.join(", ")}');

      final swahili =
          tags.where((t) => t.toLowerCase().startsWith('sw')).toList();
      debugPrint('[SpeechService] Swahili locales available: '
          '${swahili.isEmpty ? "NONE - a sw_TZ request will silently fall back to the system default" : swahili.join(", ")}');
    } catch (e) {
      debugPrint('[SpeechService] Could not enumerate locales: $e');
    }
  }

  Future<void> start() async {
    if (!_initialized) {
      final ok = await initialize(locale: _locale);
      if (!ok) {
        debugPrint('[SpeechService] Skipping start: SpeechToText is not '
            'available on this device.');
        _statusCtrl.add(AiStatus.idle);
        return;
      }
    }
    _wantRunning = true;
    _consecutiveErrors = 0;
    await _startListening();
  }

  Future<void> stop() async {
    _wantRunning = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    if (!_listening) return;
    _listening = false;
    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('[SpeechService] stop() error (non-fatal): $e');
    }
    _statusCtrl.add(AiStatus.idle);
  }

  /// Pauses or resumes capture without tearing down the pipeline.
  ///
  /// Wired to the in-call mic button. The call is video-only, so there is no
  /// audio track left to mute — "mute" now means "stop listening for
  /// captions", which is the control a hearing user actually wants.
  Future<void> setPaused(bool paused) async {
    if (paused) {
      debugPrint('[SpeechService] Paused by user');
      await stop();
    } else {
      debugPrint('[SpeechService] Resumed by user');
      await start();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _resultCtrl.close();
    await _statusCtrl.close();
  }

  // ─────────────────────────────────────────────
  // LISTENING
  // ─────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_wantRunning || _listening || _recovering) return;
    _listening = true;
    _peakLevel = -2.0;
    _lastEmitted = '';
    _statusCtrl.add(AiStatus.listening);

    try {
      await _stt.listen(
        localeId: _locale,
        listenFor: _listenFor,
        pauseFor: _pauseFor,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          // We do our own restarting on a schedule we control; letting the
          // plugin cancel on error just adds a second, competing path.
          cancelOnError: false,
        ),
        onSoundLevelChange: _onSoundLevel,

        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          // Any real speech means the pipeline is healthy — forget past errors.
          _consecutiveErrors = 0;

          if (result.finalResult) {
            debugPrint('[SpeechService] FINAL: "$words" '
                '(mic peak level: ${_peakLevel.toStringAsFixed(1)})');
          }

          // Emit partials too, so the deaf peer sees the caption build up
          // live rather than appearing only once the sentence is finished.
          // Suppress only an exact repeat of what we last sent.
          if (words.toLowerCase() == _lastEmitted) return;

          if (result.finalResult || words.length > 2) {
            _lastEmitted = words.toLowerCase();
            debugPrint('[SpeechService] EMITTING: "$words" '
                '(final: ${result.finalResult})');
            _resultCtrl.add(TranslationMessage(
              text: words,
              source: 'speech',
              language: languageTag,
            ));
          }
        },
      );
    } catch (e) {
      debugPrint('[SpeechService] Error during listen: $e');
      _listening = false;
      _statusCtrl.add(AiStatus.error);
      _handleError(isPermanent: false);
    }
  }

  // ─────────────────────────────────────────────
  // RECOVERY
  // ─────────────────────────────────────────────

  /// Single restart path. Previously there were two independent delayed
  /// restarts (from onError and from the status handler) which could stack up
  /// and race each other.
  ///
  /// A `permanent` error means the plugin has torn down its recognizer and
  /// will not produce anything until it is initialized again — so recovery
  /// has to re-initialize, not just call listen() again.
  void _handleError({required bool isPermanent}) {
    if (!_wantRunning) return;

    _consecutiveErrors++;
    // 1s, 2s, 4s, 8s, capped — so a device with no recognizer at all does not
    // spin at full speed for the whole call.
    final delaySec = (1 << (_consecutiveErrors - 1).clamp(0, 4)).clamp(1, 15);
    debugPrint('[SpeechService] Restart #$_consecutiveErrors in ${delaySec}s '
        '(permanent: $isPermanent)');

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(seconds: delaySec), () async {
      if (!_wantRunning) return;
      if (isPermanent) await _reinitialize();
      await _startListening();
    });
  }

  /// Rebuilds the plugin's internal recognizer after a permanent error.
  Future<void> _reinitialize() async {
    if (_recovering) return;
    _recovering = true;
    debugPrint('[SpeechService] Re-initializing after permanent error');
    try {
      await _stt.cancel();
    } catch (_) {/* best effort */}
    _initialized = false;
    _listening = false;
    try {
      await initialize(locale: _locale);
    } finally {
      _recovering = false;
    }
  }

  // ─────────────────────────────────────────────
  // INTERNAL
  // ─────────────────────────────────────────────

  /// Reports the microphone input level.
  ///
  /// Range is roughly -2 (silence) to 10 (loud). -2 while someone is speaking
  /// means the mic is blocked — the failure this whole change exists to fix,
  /// now observable instead of guessed at.
  void _onSoundLevel(double level) {
    if (level > _peakLevel) _peakLevel = level;
    final now = DateTime.now();
    if (now.difference(_lastLevelLog) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastLevelLog = now;
    debugPrint('[SpeechService] Mic level: ${level.toStringAsFixed(1)} '
        '(peak ${_peakLevel.toStringAsFixed(1)})');
  }

  void _onPluginStatus(String status) {
    // Plugin status strings: "listening" | "notListening" | "done"
    if (status == 'listening') {
      _statusCtrl.add(AiStatus.listening);
      return;
    }

    if (status == 'done' || status == 'notListening') {
      // Expected after `pauseFor` of silence, or after `listenFor` elapses.
      // Not an error — recycle the recognizer so the next sentence is caught.
      debugPrint('[SpeechService] Session ended ($status). '
          'Mic peak level was ${_peakLevel.toStringAsFixed(1)}.');
      _listening = false;
      _statusCtrl.add(AiStatus.idle);
      if (_wantRunning) {
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 400), () {
          if (_wantRunning) _startListening();
        });
      }
    }
  }
}
