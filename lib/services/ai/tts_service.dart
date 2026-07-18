// TTSService
// ─────────────────────────────────────────────────────────────
// Wraps flutter_tts. Used in the Deaf → Hearing direction:
// the recognized gesture label is spoken aloud through the device.
//
// Exposes only what the controller needs.

import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> initialize({String language = 'en-US'}) async {
    // Always update language so it can be switched between calls.
    await _tts.setLanguage(language);
    if (_ready) return;
    await _tts.setSpeechRate(0.5);  // mid-pace, more natural
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text) async {
    if (!_ready) await initialize();
    if (text.trim().isEmpty) return;

    // Normalize labels for natural speech:
    //   "gesture.home" -> "home"
    //   "thank_you" -> "thank you"
    String normalized = text.trim();
    if (normalized.startsWith('gesture.')) normalized = normalized.substring(8);
    normalized = normalized.replaceAll('_', ' ').trim();
    // Capitalize first letter for better TTS naturalness
    if (normalized.isNotEmpty) {
      normalized = normalized[0].toUpperCase() + (normalized.length > 1 ? normalized.substring(1) : '');
    }

    await _tts.stop(); // cancel any previous utterance
    await _tts.speak(normalized);
  }

  Future<void> stop() async => _tts.stop();
  Future<void> dispose() async => _tts.stop();
}