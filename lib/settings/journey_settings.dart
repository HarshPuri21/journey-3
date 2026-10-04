import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/storage.dart';

/// Global Journey preferences. Furigana is handled here once, not per lesson:
/// every ruby-capable widget reads [furiganaEnabled].
class JourneySettings extends ChangeNotifier {
  JourneySettings(this._storage);

  static const storageKey = 'n5journey.settings';
  final JourneyStorage _storage;

  bool _furigana = true;
  bool _kanaNoticeDismissed = false;

  bool get furiganaEnabled => _furigana;
  bool get kanaNoticeDismissed => _kanaNoticeDismissed;

  Future<void> load() async {
    try {
      final raw = await _storage.read(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) {
          _furigana = j['furigana'] is bool ? j['furigana'] as bool : true;
          _kanaNoticeDismissed = j['kanaNoticeDismissed'] == true;
        }
      }
    } catch (e) {
      debugPrint('JourneySettings.load failed, using defaults: $e');
    }
    notifyListeners();
  }

  Future<void> setFurigana(bool value) async {
    if (_furigana == value) return;
    _furigana = value;
    notifyListeners();
    await _save();
  }

  Future<void> dismissKanaNotice() async {
    _kanaNoticeDismissed = true;
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _storage.write(storageKey,
      jsonEncode({'schemaVersion': 1, 'furigana': _furigana, 'kanaNoticeDismissed': _kanaNoticeDismissed}));
}
