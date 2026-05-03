import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/storage/license_config_storage.dart';
import '../../license/data/license_repository.dart';
import '../../license/domain/license_activation.dart';
import '../data/vpn_repository.dart';
import '../domain/vpn_connection_state.dart';

/// Orchestrates license cache + tunnel actions. UI listens via [Listenable].
class VpnSessionController extends ChangeNotifier {
  VpnSessionController({
    required VpnRepository vpnRepository,
    required LicenseRepository licenseRepository,
    required SharedPreferences prefs,
    required LicenseConfigStorage configStorage,
    required String deviceId,
    String? initialV2RayConfig,
  }) : _vpn = vpnRepository,
       _license = licenseRepository,
       _prefs = prefs,
       _configStorage = configStorage,
       _deviceId = deviceId,
       _memoryV2RayConfig = initialV2RayConfig {
    _log('controller init');
    _vpnSub = _vpn.states.listen((state) {
      _log('vpnState=$state');
      notifyListeners();
    });
  }

  late final StreamSubscription<VpnConnectionState> _vpnSub;

  static const _kExpires = 'novanet_license_expires_iso';

  final VpnRepository _vpn;
  final LicenseRepository _license;
  final SharedPreferences _prefs;
  final LicenseConfigStorage _configStorage;
  final String _deviceId;

  String? _memoryV2RayConfig;
  final List<String> _debugEvents = <String>[];

  void _log(String msg) {
    _debugEvents.add('${DateTime.now().toIso8601String()} $msg');
    if (_debugEvents.length > 300) {
      _debugEvents.removeRange(0, _debugEvents.length - 300);
    }
  }

  VpnConnectionState get tunnelState => _vpn.currentState;

  String? get cachedV2RayConfig => _memoryV2RayConfig;

  DateTime? get licenseExpiresAt {
    final s = _prefs.getString(_kExpires);
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  bool get hasActiveLicense {
    final exp = licenseExpiresAt;
    if (exp == null) return false;
    return exp.isAfter(DateTime.now());
  }

  bool get isLicenseExpired {
    final exp = licenseExpiresAt;
    if (exp == null) return false;
    return !exp.isAfter(DateTime.now());
  }

  String get deviceId => _deviceId;

  Future<void> activateLicense(String formattedKey) async {
    _log('activate start keyLength=${formattedKey.length}');
    final result = await _license.activate(
      formattedKey: formattedKey,
      deviceId: _deviceId,
    );
    switch (result) {
      case LicenseActivated(:final v2RayConfigJson, :final expiresAt):
        _log(
          'activate success cfgBytes=${v2RayConfigJson.length} exp=${expiresAt.toIso8601String()}',
        );
        await _configStorage.write(v2RayConfigJson);
        _memoryV2RayConfig = v2RayConfigJson;
        await _prefs.setString(_kExpires, expiresAt.toIso8601String());
        notifyListeners();
      case LicenseActivationFailure(:final message):
        _log('activate failure=$message');
        throw LicenseException(message);
    }
  }

  Future<ActivationTransportDiagnostics> diagnoseActivationTransport() async {
    final repo = _license;
    if (repo is! ActivationDiagnosticsCapable) {
      throw const LicenseException(
        'Diagnostics are available only when Firebase mode is enabled.',
      );
    }
    final diagnosticsRepo = repo as ActivationDiagnosticsCapable;
    return diagnosticsRepo.diagnoseActivationTransport(deviceId: _deviceId);
  }

  Future<void> disconnect() async {
    _log('disconnect start');
    await _vpn.stop();
    _log('disconnect done');
    notifyListeners();
  }

  Future<void> connect() async {
    _log('connect start hasActiveLicense=$hasActiveLicense');
    if (!hasActiveLicense) {
      _log('connect blocked no active license');
      throw LicenseException(AppStrings.noLicenseHint);
    }
    final cfg = cachedV2RayConfig;
    if (cfg == null || cfg.isEmpty) {
      _log('connect blocked missing cached config');
      throw LicenseException(AppStrings.noLicenseHint);
    }
    _log('connect using configBytes=${cfg.length}');
    await _vpn.start(cfg);
    _log('connect done');
    notifyListeners();
  }

  /// Clears local activation (does not call backend revoke).
  Future<void> clearLicenseCache() async {
    _log('clearLicenseCache start');
    await _configStorage.clear();
    _memoryV2RayConfig = null;
    await _prefs.remove(_kExpires);
    if (_vpn.currentState == VpnConnectionState.connected ||
        _vpn.currentState == VpnConnectionState.connecting) {
      await _vpn.stop();
    }
    notifyListeners();
  }

  String buildDebugReport() {
    final lines = <String>[
      '=== NovaNet Debug Report ===',
      'time=${DateTime.now().toIso8601String()}',
      'deviceId=$deviceId',
      'flags: firebase=${AppConfig.shouldUseFirebase}, nativeVpn=${AppConfig.shouldUseNativeVpn}, regions=${AppConfig.functionRegionsCsv}',
      'license: hasActive=$hasActiveLicense, expired=$isLicenseExpired, expiresAt=${licenseExpiresAt?.toIso8601String() ?? 'null'}',
      'tunnelState=$tunnelState',
      'cachedConfigBytes=${cachedV2RayConfig?.length ?? 0}',
      '',
      'controllerEvents:',
      ..._debugEvents.map((e) => '  $e'),
      '',
      'vpnRepositoryDebug:',
      if (_vpn is VpnDiagnosticsCapable)
        ...(_vpn as VpnDiagnosticsCapable).buildVpnDebugReport().split('\n')
      else
        '  repository does not expose debug info',
    ];
    return lines.join('\n');
  }

  @override
  void dispose() {
    unawaited(_vpnSub.cancel());
    _vpn.dispose();
    super.dispose();
  }
}

class LicenseException implements Exception {
  const LicenseException(this.message);
  final String message;

  @override
  String toString() => message;
}
