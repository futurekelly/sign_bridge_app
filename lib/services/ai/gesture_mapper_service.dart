// GestureMapperService
// ─────────────────────────────────────────────────────────────
// Maps a recognized text string → a GIF asset key (or null).
//
// Used in BOTH directions:
//   • Deaf → Hearing : maps gesture label → GIF (already 1:1)
//   • Hearing → Deaf : maps spoken word(s) → matching sign GIF
//
// Keeps a tiny dictionary in code so the demo runs without
// any external config. Extend freely.

class GestureMapperService {
  // Canonical mapping of "phrase" → "asset key under assets/gifs/<key>.gif"
  static const Map<String, String> _dictionary = {
    'hello': 'hello',
    'hi': 'hello',
    'thank you': 'thank_you',
    'thanks': 'thank_you',
    'thank_you': 'thank_you',
    'help': 'help',
    'yes': 'yes',
    'no': 'no',
    'wewe': 'wewe',
    'mimi': 'mimi',
  };

  /// Best-effort match for the input text.
  /// Returns null if no mapping exists (UI must handle that gracefully).
  static String? mapTextToGifKey(String text) {
    if (text.trim().isEmpty) return null;
    final lower = text.toLowerCase().trim();

    // 1) Direct hit.
    if (_dictionary.containsKey(lower)) return _dictionary[lower];

    // 2) Token-level scan: pick first matching word/phrase.
    final tokens = lower.split(RegExp(r'\s+'));
    for (final t in tokens) {
      if (_dictionary.containsKey(t)) return _dictionary[t];
    }

    // 3) Substring fallback (for phrases like "say hello to her").
    for (final entry in _dictionary.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    return null;
  }

  /// Resolves a GIF asset path from a key.
  /// Returns null if the key is null/empty.
  static String? assetPathForKey(String? key) {
    if (key == null || key.isEmpty) return null;
    return 'assets/gifs/$key.gif';
  }
}