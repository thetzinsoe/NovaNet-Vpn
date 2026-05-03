import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable per-install identifier for backend binding (`device_id` in Firestore).
class DeviceIdService {
  DeviceIdService(this._prefs);

  final SharedPreferences _prefs;

  static const _storageKey = 'novanet_device_install_id';

  String getOrCreate() {
    final existing = _prefs.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _randomId();
    _prefs.setString(_storageKey, id);
    return id;
  }

  static String _randomId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
