import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/services/device_id_service.dart';
import '../core/storage/license_config_storage.dart';
import '../features/license/data/firebase_license_repository.dart';
import '../features/license/data/license_repository.dart';
import '../features/vpn/application/vpn_session_controller.dart';
import '../features/vpn/data/flutter_v2ray_vpn_repository.dart';
import '../features/vpn/data/vpn_repository.dart';
import 'nova_app.dart';

LicenseRepository _resolveLicense() {
  if (AppConfig.shouldUseFirebase) {
    return FirebaseLicenseRepository();
  }
  return StubLicenseRepository();
}

VpnRepository _resolveVpn() {
  if (!AppConfig.shouldUseNativeVpn) {
    return StubVpnRepository();
  }
  return FlutterV2rayVpnRepository();
}

/// Root widget with dependency injection. Override repos in tests.
Widget novaProvidersApp({
  required SharedPreferences prefs,
  String? initialV2RayConfig,
  LicenseConfigStorage? configStorage,
  VpnRepository? vpnRepository,
  LicenseRepository? licenseRepository,
}) {
  final vpn = vpnRepository ?? _resolveVpn();
  final license = licenseRepository ?? _resolveLicense();
  final deviceId = DeviceIdService(prefs).getOrCreate();
  final cfgStorage = configStorage ?? SecureLicenseConfigStorage(prefs);

  return MultiProvider(
    providers: [
      Provider<SharedPreferences>.value(value: prefs),
      Provider<LicenseConfigStorage>.value(value: cfgStorage),
      Provider<VpnRepository>.value(value: vpn),
      Provider<LicenseRepository>.value(value: license),
      ChangeNotifierProvider(
        create: (_) => VpnSessionController(
          vpnRepository: vpn,
          licenseRepository: license,
          prefs: prefs,
          configStorage: cfgStorage,
          deviceId: deviceId,
          initialV2RayConfig: initialV2RayConfig,
        ),
      ),
    ],
    child: const NovaApp(),
  );
}
