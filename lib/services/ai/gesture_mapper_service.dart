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
  // Expanded dictionary: map recognized label or spoken variants → canonical gifKey (same as label key)
  static const Map<String, String> _dictionary = {
    'hello': 'hello',
    'yes': 'yes',
    'no': 'no',
    'help': 'help',
    'book': 'book',
    'car': 'car',
    'bus': 'bus',
    'phone': 'phone',
    'drink': 'drink',
    'water': 'water',
    'eat': 'eat',
    'food': 'food',
    'fire': 'fire',
    'school': 'school',
    'teacher': 'teacher',
    'student': 'student',
    'hospital': 'hospital',
    'doctor': 'doctor',
    'medicine': 'medicine',
    'police': 'police',
    'work': 'work',
    'shop': 'shop',
    'money': 'money',
    'home': 'home',
    'safe': 'safe',
    'danger': 'danger',
    'sleep': 'sleep',
    'walk': 'walk',
    'run': 'run',
    'stop': 'stop',
    'sit': 'sit',
    'stand': 'stand',
    'mother': 'mother',
    'father': 'father',
    'baby': 'baby',
    'boy': 'boy',
    'girl': 'girl',
    'child': 'child',
    'woman': 'woman',
    'man': 'man',
    'friend': 'friend',
    'come': 'come',
    'go': 'go',
    'computer': 'computer',
    'bread': 'bread',
    'sorry': 'sorry',
    'please': 'please',
    'thank_you': 'thank_you',
  };

  /// Best-effort match for the input text.
  /// Returns null if no mapping exists (UI must handle that gracefully).
  static String? mapTextToGifKey(String text) {
    if (text.trim().isEmpty) return null;
    var lower = text.toLowerCase().trim();

    // Strip leading 'gesture.' if present
    if (lower.startsWith('gesture.')) lower = lower.substring(8);
    // Normalize underscores to spaces for matching
    lower = lower.replaceAll('_', ' ').trim();

    // 1) Direct hit against canonical keys (try both underscore and space forms)
    if (_dictionary.containsKey(lower)) return _dictionary[lower];
    final underscoreKey = lower.replaceAll(' ', '_');
    if (_dictionary.containsKey(underscoreKey)) return _dictionary[underscoreKey];

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