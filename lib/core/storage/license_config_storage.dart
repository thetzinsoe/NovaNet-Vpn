import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sensitive V2Ray JSON — not stored in plain SharedPreferences.
abstract class LicenseConfigStorage {
  Future<void> write(String v2RayConfigJson);
  Future<String?> read();
  Future<void> clear();
}

class SecureLicenseConfigStorage implements LicenseConfigStorage {
  SecureLicenseConfigStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _secureKey = 'novanet_v2ray_config_secure';
  static const _legacyPrefsKey = 'novanet_v2ray_config_cache';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<void> write(String v2RayConfigJson) async {
    await _storage.write(key: _secureKey, value: v2RayConfigJson);
    if (_prefs.containsKey(_legacyPrefsKey)) {
      await _prefs.remove(_legacyPrefsKey);
    }
  }

  @override
  Future<String?> read() async {
    final secure = await _storage.read(key: _secureKey);
    if (secure != null && secure.isNotEmpty) return secure;

    final legacy = _prefs.getString(_legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await write(legacy);
      await _prefs.remove(_legacyPrefsKey);
      return legacy;
    }
    return null;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _secureKey);
    await _prefs.remove(_legacyPrefsKey);
  }
}
