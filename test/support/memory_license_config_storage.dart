import 'package:novanet_vpn/core/storage/license_config_storage.dart';

/// In-memory config store for tests (avoids platform secure storage).
class MemoryLicenseConfigStorage implements LicenseConfigStorage {
  String? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String v2RayConfigJson) async {
    _value = v2RayConfigJson;
  }
}
