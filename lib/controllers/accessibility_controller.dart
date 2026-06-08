// AccessibilityController — stores the user's accessibility role
// and preferences. Persisted to Hive.

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/enums.dart';
import '../core/translations.dart';

class AccessibilityController extends ChangeNotifier {
  final Box _box = Hive.box('app_settings');

  AccessibilityController() {
    _load();
  }

  // ── State ──
  UserRole _role = UserRole.both;
  bool _captionsEnabled = true;
  double _captionFontSize = 16.0;
  bool _visualNotifications = false;
  String _languageCode = 'en';

  // ── Getters ──
  UserRole get role => _role;
  bool get captionsEnabled => _captionsEnabled;
  double get captionFontSize => _captionFontSize;
  bool get visualNotifications => _visualNotifications;
  String get languageCode => _languageCode;

  // ── Convenience ──
  bool get isDeaf    => _role == UserRole.deaf;
  bool get isHearing => _role == UserRole.hearing;
  bool get isBoth    => _role == UserRole.both;

  /// Translate [key] using the current language.
  String t(String key) => AppTranslations.t(key, _languageCode);

  // ── Setters (persist + notify) ──

  Future<void> setRole(UserRole role) async {
    _role = role;
    // Auto-adjust defaults based on role
    if (role == UserRole.deaf) {
      _captionsEnabled = true;
      _visualNotifications = true;
      _captionFontSize = 18.0;
    } else if (role == UserRole.hearing) {
      _captionsEnabled = false;
      _visualNotifications = false;
      _captionFontSize = 16.0;
    } else {
      _captionsEnabled = true;
      _visualNotifications = true;
      _captionFontSize = 16.0;
    }
    await _save();
    notifyListeners();
  }

  Future<void> setCaptionsEnabled(bool v) async {
    _captionsEnabled = v;
    await _save();
    notifyListeners();
  }

  Future<void> setCaptionFontSize(double v) async {
    _captionFontSize = v.clamp(12.0, 28.0);
    await _save();
    notifyListeners();
  }

  Future<void> setVisualNotifications(bool v) async {
    _visualNotifications = v;
    await _save();
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    await _save();
    notifyListeners();
  }

  // ── Persistence ──

  void _load() {
    final roleStr = _box.get('userRole', defaultValue: 'both') as String;
    _role = UserRoleX.fromString(roleStr);
    _captionsEnabled = _box.get('captionsEnabled', defaultValue: true) as bool;
    _captionFontSize = (_box.get('captionFontSize', defaultValue: 16.0) as num).toDouble();
    _visualNotifications = _box.get('visualNotifications', defaultValue: false) as bool;
    _languageCode = _box.get('languageCode', defaultValue: 'en') as String;
  }

  Future<void> _save() async {
    await _box.put('userRole', _role.value);
    await _box.put('captionsEnabled', _captionsEnabled);
    await _box.put('captionFontSize', _captionFontSize);
    await _box.put('visualNotifications', _visualNotifications);
    await _box.put('languageCode', _languageCode);
  }
}
