// SpeechService
// ─────────────────────────────────────────────────────────────
// Real Speech-to-Text using the speech_to_text plugin.
// Emits the same TranslationMessage shape as GestureRecognitionService,
// keeping the AI pipeline uniform.

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

  /// Locale: "en_US" by default. Pass "sw_TZ" for Swahili.
  String _locale = 'en_US';
  String get languageTag => _locale.split('_').first; // "en" / "sw"

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  Future<bool> initialize({String locale = 'en_US'}) async {
    _locale = locale;
    if (_initialized) return true;

    try {
      _initialized = await _stt.initialize(
        onStatus: _onPluginStatus,
        onError: (e) {
          debugPrint('[SpeechService] SpeechToText error callback: $e');
          _statusCtrl.add(AiStatus.error);
          // Auto-restart after error if still wanted
          if (_wantRunning) {
            Future.delayed(const Duration(seconds: 1), _startListening);
          }
        },
      );
    } catch (e) {
      debugPrint('[SpeechService] Failed to initialize SpeechToText (not supported on this device?): $e');
      _initialized = false;
    }
    return _initialized;
  }

  Future<void> start() async {
    if (!_initialized) {
      final ok = await initialize(locale: _locale);
      if (!ok) {
        debugPrint('[SpeechService] Skipping start: SpeechToText is not available on this device.');
        _statusCtrl.add(AiStatus.idle);
        return;
      }
    }
    _wantRunning = true;
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!_wantRunning || _listening) return;
    _listening = true;
    _statusCtrl.add(AiStatus.listening);

    try {
      await _stt.listen(
        localeId: _locale,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
        ),
        onResult: (result) {
          final words = result.recognizedWords.trim().toLowerCase();
          if (words.isEmpty) return;

          // Only emit if:
          //   (a) STT declared this a final result, OR
          //   (b) Partial text exactly matches a vocabulary word (catch short words early).
          // This prevents mid-word fragments ("hel", "than") from displaying as captions.
          const vocab = {
            'hello', 'habari', 'hi',
            'yes',   'ndiyo',
            'no',    'hapana',
            'help',  'msaada',
            'thank you', 'thank_you', 'asante', 'thanks',
          };
          final matchesVocab = vocab.any((v) => words == v || words.contains(v));

          if (result.finalResult || matchesVocab) {
            _resultCtrl.add(TranslationMessage(
              text: result.recognizedWords.trim(),
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
      // Auto-restart after 1 second
      if (_wantRunning) {
        Future.delayed(const Duration(seconds: 1), _startListening);
      }
    }
  }

  Future<void> stop() async {
    _wantRunning = false;
    if (!_listening) return;
    _listening = false;
    await _stt.stop();
    _statusCtrl.add(AiStatus.idle);
  }

  Future<void> dispose() async {
    await stop();
    await _resultCtrl.close();
    await _statusCtrl.close();
  }

  // ─────────────────────────────────────────────
  // INTERNAL
  // ─────────────────────────────────────────────

  void _onPluginStatus(String status) {
    // Plugin status strings: "listening" | "notListening" | "done"
    debugPrint('[SpeechService] Plugin status: $status');
    if (status == 'listening') {
      _statusCtrl.add(AiStatus.listening);
    } else if (status == 'done' || status == 'notListening') {
      // STT plugins auto-stop on silence on most Android devices.
      // Auto-restart so the hearing user doesn't need to tap mic again.
      _listening = false;
      _statusCtrl.add(AiStatus.idle);
      if (_wantRunning) {
        Future.delayed(const Duration(milliseconds: 500), _startListening);
      }
    }
  }
}

