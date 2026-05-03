import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_errors.dart';
import '../domain/license_activation.dart';
import 'license_repository.dart';

/// Calls HTTPS callable `activateVpnKey` — see `docs/FIREBASE.md`.
class FirebaseLicenseRepository
    implements LicenseRepository, ActivationDiagnosticsCapable {
  FirebaseLicenseRepository({
    FirebaseFunctions? functions,
    http.Client? httpClient,
    List<String>? regions,
    List<Uri>? httpFallbackUris,
  }) : _regions = _normalizeRegions(regions ?? _regionsFromConfig()),
       _httpFallbackUris = _normalizeUris(
         httpFallbackUris ?? _httpUrisFromConfig(),
       ),
       _primaryFn =
           functions ??
           FirebaseFunctions.instanceFor(
             region: _normalizeRegions(regions ?? _regionsFromConfig()).first,
           ),
       _http = httpClient ?? http.Client();

  static const _region = 'us-central1';
  final List<String> _regions;
  final List<Uri> _httpFallbackUris;
  final FirebaseFunctions _primaryFn;
  final http.Client _http;

  @override
  Future<LicenseActivationResult> activate({
    required String formattedKey,
    required String deviceId,
  }) async {
    try {
      final callable = _primaryFn.httpsCallable('activateVpnKey');
      final result = await callable.call(<String, dynamic>{
        'key': formattedKey,
        'deviceId': deviceId,
      });
      return _mapSuccess(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (_shouldUseHttpFallback(e.code)) {
        final fallback = await _activateViaHttp(
          formattedKey: formattedKey,
          deviceId: deviceId,
        );
        if (fallback != null) return fallback;
        if (kDebugMode) {
          return LicenseActivationFailure(
            '${_mapFunctionsException(e)} (HTTP fallback unreachable)',
          );
        }
      }
      return LicenseActivationFailure(_mapFunctionsException(e));
    } catch (e) {
      return LicenseActivationFailure('${AppErrors.network} ($e)');
    }
  }

  Future<LicenseActivationResult?> _activateViaHttp({
    required String formattedKey,
    required String deviceId,
  }) async {
    LicenseActivationResult? lastTransientFailure;
    Object? lastTransportError;
    var hadTransportError = false;
    final uris = _buildFallbackUris();
    for (final uri in uris) {
      try {
        final response = await _http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'key': formattedKey, 'deviceId': deviceId}),
            )
            .timeout(const Duration(seconds: 15));
        final parsed = _tryJson(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _mapSuccess(parsed);
        }
        final msg = _mapHttpFailure(response.statusCode, parsed);
        if (_isDefinitiveHttpStatus(response.statusCode)) {
          return LicenseActivationFailure(msg);
        }
        lastTransientFailure = LicenseActivationFailure(msg);
      } catch (e) {
        hadTransportError = true;
        lastTransportError = e;
        // Try next fallback endpoint/region.
      }
    }
    if (hadTransportError) {
      if (kDebugMode && lastTransportError != null) {
        return LicenseActivationFailure(
          '${AppErrors.activationTransportBlocked} ($lastTransportError)',
        );
      }
      return const LicenseActivationFailure(
        AppErrors.activationTransportBlocked,
      );
    }
    return lastTransientFailure;
  }

  List<Uri> _buildFallbackUris() {
    final byConfig = _httpFallbackUris;
    if (byConfig.isNotEmpty) return byConfig;
    try {
      final projectId = Firebase.app().options.projectId;
      return _regions
          .map(
            (region) => Uri.parse(
              'https://$region-$projectId.cloudfunctions.net/activateVpnKeyHttp',
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <Uri>[];
    }
  }

  static List<String> _regionsFromConfig() {
    return AppConfig.functionRegionsCsv.split(',');
  }

  static List<Uri> _httpUrisFromConfig() {
    final raw = AppConfig.functionHttpUrlsCsv.trim();
    if (raw.isEmpty) return const <Uri>[];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(Uri.tryParse)
        .whereType<Uri>()
        .toList(growable: false);
  }

  static List<String> _normalizeRegions(List<String> regions) {
    final normalized = regions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isNotEmpty) return normalized;
    return const <String>[_region];
  }

  static List<Uri> _normalizeUris(List<Uri> uris) {
    final normalized = uris
        .where((u) => u.hasScheme && u.host.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return normalized;
  }

  static bool _isDefinitiveHttpStatus(int statusCode) {
    return statusCode == 400 ||
        statusCode == 403 ||
        statusCode == 404 ||
        statusCode == 412;
  }

  static bool _isCallableReachableCode(String code) {
    return code == 'invalid-argument' ||
        code == 'not-found' ||
        code == 'permission-denied' ||
        code == 'failed-precondition';
  }

  @override
  Future<ActivationTransportDiagnostics> diagnoseActivationTransport({
    required String deviceId,
  }) async {
    final callableStart = DateTime.now();
    var callableReachable = false;
    var callableDetail = 'No response';

    try {
      final callable = _primaryFn.httpsCallable('activateVpnKey');
      await callable.call(<String, dynamic>{
        'key': 'AAAA-AAAA-AAAA',
        'deviceId': deviceId,
      });
      callableReachable = true;
      callableDetail = 'Callable request succeeded';
    } on FirebaseFunctionsException catch (e) {
      callableReachable = _isCallableReachableCode(e.code);
      callableDetail =
          'Firebase code: ${e.code}${e.message == null ? '' : ', ${e.message}'}';
    } catch (e) {
      callableDetail = 'Transport error: $e';
    }
    final callableDuration = DateTime.now()
        .difference(callableStart)
        .inMilliseconds;

    final checks = <HttpEndpointDiagnostics>[];
    for (final uri in _buildFallbackUris()) {
      final start = DateTime.now();
      try {
        final response = await _http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(<String, dynamic>{'key': 'BAD', 'deviceId': ''}),
            )
            .timeout(const Duration(seconds: 10));
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        checks.add(
          HttpEndpointDiagnostics(
            url: uri.toString(),
            reachable: true,
            detail: 'HTTP endpoint responded',
            durationMs: elapsed,
            statusCode: response.statusCode,
          ),
        );
      } catch (e) {
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        checks.add(
          HttpEndpointDiagnostics(
            url: uri.toString(),
            reachable: false,
            detail: 'Transport error: $e',
            durationMs: elapsed,
          ),
        );
      }
    }

    return ActivationTransportDiagnostics(
      callableReachable: callableReachable,
      callableDetail: callableDetail,
      callableDurationMs: callableDuration,
      httpChecks: checks,
    );
  }

  static bool _shouldUseHttpFallback(String code) {
    return code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        code == 'internal';
  }

  Object? _tryJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _mapHttpFailure(int statusCode, Object? parsed) {
    if (parsed is Map) {
      final map = Map<String, dynamic>.from(parsed);
      final code = map['error'];
      final message = map['message'];
      if (code is String) {
        if (code == 'invalid-argument' || code == 'not-found') {
          return AppErrors.invalidKey;
        }
        if (code == 'permission-denied' || code == 'failed-precondition') {
          return AppErrors.deviceMismatch;
        }
        if (code == 'unavailable') {
          return AppErrors.serverBusy;
        }
      }
      if (message is String && message.isNotEmpty && kDebugMode) {
        return '${AppErrors.activationFailed} ($message)';
      }
    }
    if (statusCode == 404 || statusCode == 400) return AppErrors.invalidKey;
    if (statusCode == 403 || statusCode == 412) return AppErrors.deviceMismatch;
    if (statusCode >= 500) return AppErrors.serverBusy;
    return AppErrors.activationFailed;
  }

  LicenseActivationResult _mapSuccess(Object? data) {
    if (data is! Map) {
      return const LicenseActivationFailure(AppErrors.activationFailed);
    }
    final map = Map<String, dynamic>.from(data);
    final v2 = map['v2RayConfigJson'] ?? map['config'];
    final exp = map['expiresAt'] ?? map['expires_at'];
    if (v2 is! String || v2.isEmpty) {
      return const LicenseActivationFailure(AppErrors.activationFailed);
    }
    DateTime? expires;
    if (exp is String) {
      expires = DateTime.tryParse(exp);
    } else if (exp is Map) {
      final m = Map<String, dynamic>.from(exp);
      final seconds = m['_seconds'] ?? m['seconds'];
      if (seconds is int) {
        expires = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    expires ??= DateTime.now().add(const Duration(days: 30));
    return LicenseActivated(v2RayConfigJson: v2, expiresAt: expires);
  }

  String _mapFunctionsException(FirebaseFunctionsException e) {
    final code = e.code;
    final debugSuffix = kDebugMode
        ? ' (Firebase code: $code${e.message == null ? '' : ', ${e.message}'})'
        : '';
    if (code == 'not-found' || code == 'invalid-argument') {
      return '${AppErrors.invalidKey}$debugSuffix';
    }
    if (code == 'permission-denied' || code == 'failed-precondition') {
      return '${AppErrors.deviceMismatch}$debugSuffix';
    }
    if (code == 'resource-exhausted') {
      return '${AppErrors.serverBusy}$debugSuffix';
    }
    if (code == 'unavailable') {
      return '${AppErrors.activationTransportBlocked}$debugSuffix';
    }
    if (code == 'deadline-exceeded' ||
        e.message?.toLowerCase().contains('network') == true) {
      return '${AppErrors.network}$debugSuffix';
    }
    return e.message?.isNotEmpty == true
        ? e.message!
        : AppErrors.activationFailed;
  }
}
