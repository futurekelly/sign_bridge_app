// SpeechService
// ─────────────────────────────────────────────────────────────
// Real Speech-to-Text using the speech_to_text plugin.
// Emits the same TranslationMessage shape as GestureRecognitionService,
// keeping the AI pipeline uniform.

import 'dart:async';
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

  /// Locale: "en_US" by default. Pass "sw_KE" or similar for Swahili.
  String _locale = 'en_US';
  String get languageTag => _locale.split('_').first; // "en" / "sw"

  // ─────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────

  Future<bool> initialize({String locale = 'en_US'}) async {
    _locale = locale;
    if (_initialized) return true;

    _initialized = await _stt.initialize(
      onStatus: _onPluginStatus,
      onError: (e) {
        _statusCtrl.add(AiStatus.error);
      },
    );
    return _initialized;
  }

  Future<void> start() async {
    if (!_initialized) {
      final ok = await initialize(locale: _locale);
      if (!ok) {
        _statusCtrl.add(AiStatus.error);
        return;
      }
    }
    if (_listening) return;

    _statusCtrl.add(AiStatus.listening);
    _listening = true;

    await _stt.listen(
      localeId: _locale,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        // Only emit final results to avoid spamming UI/DataChannel.
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _resultCtrl.add(TranslationMessage(
            text: result.recognizedWords.trim(),
            source: 'speech',
            language: languageTag,
            // gifKey is set later by the GestureMapperService.
          ));
        }
      },
    );
  }

  Future<void> stop() async {
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
    if (status == 'listening') {
      _statusCtrl.add(AiStatus.listening);
    } else if (status == 'done' || status == 'notListening') {
      // STT plugins sometimes auto-stop on silence.
      // TranslationController will decide whether to restart.
      _statusCtrl.add(AiStatus.idle);
      _listening = false;
    }
  }
}