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
    if (_ready) return;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.5);  // mid-pace, more natural
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text) async {
    if (!_ready) await initialize();
    if (text.trim().isEmpty) return;

    // Replace underscores from gesture labels for natural speech:
    //   "thank_you" → "thank you"
    final clean = text.replaceAll('_', ' ');
    await _tts.stop(); // cancel any previous utterance
    await _tts.speak(clean);
  }

  Future<void> stop() async => _tts.stop();
  Future<void> dispose() async => _tts.stop();
}