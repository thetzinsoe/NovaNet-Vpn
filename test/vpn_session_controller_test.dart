import 'package:flutter_test/flutter_test.dart';
import 'package:novanet_vpn/features/license/data/license_repository.dart';
import 'package:novanet_vpn/features/license/domain/license_activation.dart';
import 'package:novanet_vpn/features/vpn/application/vpn_session_controller.dart';
import 'package:novanet_vpn/features/vpn/data/vpn_repository.dart';
import 'package:novanet_vpn/features/vpn/domain/vpn_connection_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_license_config_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VpnSessionController', () {
    late SharedPreferences prefs;
    late MemoryLicenseConfigStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = MemoryLicenseConfigStorage();
    });

    test('activateLicense stores config and expiry', () async {
      final vpn = StubVpnRepository();
      final license = _FakeLicenseRepository();
      final session = VpnSessionController(
        vpnRepository: vpn,
        licenseRepository: license,
        prefs: prefs,
        configStorage: storage,
        deviceId: 'dev-1',
      );

      await session.activateLicense('1234-5678-9012');

      expect(session.hasActiveLicense, isTrue);
      expect(session.cachedV2RayConfig, '{"ok":true}');
      final stored = await storage.read();
      expect(stored, '{"ok":true}');

      session.dispose();
    });

    test('connect uses cached config', () async {
      final vpn = StubVpnRepository();
      final license = _FakeLicenseRepository();
      await storage.write('{"x":1}');
      prefs.setString(
        'novanet_license_expires_iso',
        DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      );

      final session = VpnSessionController(
        vpnRepository: vpn,
        licenseRepository: license,
        prefs: prefs,
        configStorage: storage,
        deviceId: 'dev-1',
        initialV2RayConfig: '{"x":1}',
      );

      await session.connect();
      expect(session.tunnelState, VpnConnectionState.connected);

      session.dispose();
    });

    test('stub license accepts alphanumeric key and connects', () async {
      final vpn = StubVpnRepository();
      final session = VpnSessionController(
        vpnRepository: vpn,
        licenseRepository: StubLicenseRepository(),
        prefs: prefs,
        configStorage: storage,
        deviceId: 'dev-1',
      );

      await session.activateLicense('URSN-B88G-A5DR');
      await session.connect();

      expect(session.hasActiveLicense, isTrue);
      expect(session.cachedV2RayConfig, isNotEmpty);
      expect(session.tunnelState, VpnConnectionState.connected);

      session.dispose();
    });
  });
}

class _FakeLicenseRepository implements LicenseRepository {
  @override
  Future<LicenseActivationResult> activate({
    required String formattedKey,
    required String deviceId,
  }) async {
    return LicenseActivated(
      v2RayConfigJson: '{"ok":true}',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
  }
}
