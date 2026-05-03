import 'dart:convert';

import '../domain/license_activation.dart';

/// Validates keys and returns V2Ray config — replace body with Firebase callable.
abstract class LicenseRepository {
  Future<LicenseActivationResult> activate({
    required String formattedKey,
    required String deviceId,
  });
}

/// Optional capability for transport diagnostics (callable + HTTP fallback).
abstract class ActivationDiagnosticsCapable {
  Future<ActivationTransportDiagnostics> diagnoseActivationTransport({
    required String deviceId,
  });
}

class ActivationTransportDiagnostics {
  const ActivationTransportDiagnostics({
    required this.callableReachable,
    required this.callableDetail,
    required this.callableDurationMs,
    required this.httpChecks,
  });

  final bool callableReachable;
  final String callableDetail;
  final int callableDurationMs;
  final List<HttpEndpointDiagnostics> httpChecks;

  bool get anyHttpReachable => httpChecks.any((c) => c.reachable);

  String toMultilineText() {
    final lines = <String>[
      'Callable (activateVpnKey): '
          '${callableReachable ? 'reachable' : 'unreachable'} '
          'in ${callableDurationMs}ms',
      '  Detail: $callableDetail',
      '',
      'HTTP fallback (activateVpnKeyHttp):',
    ];
    if (httpChecks.isEmpty) {
      lines.add('  - no configured endpoints');
    } else {
      for (final c in httpChecks) {
        final status = c.statusCode == null ? 'no-response' : '${c.statusCode}';
        lines.add(
          '  - ${c.url} -> ${c.reachable ? 'reachable' : 'unreachable'} '
          '(status: $status, ${c.durationMs}ms)',
        );
        lines.add('    ${c.detail}');
      }
    }
    return lines.join('\n');
  }
}

class HttpEndpointDiagnostics {
  const HttpEndpointDiagnostics({
    required this.url,
    required this.reachable,
    required this.detail,
    required this.durationMs,
    this.statusCode,
  });

  final String url;
  final bool reachable;
  final String detail;
  final int durationMs;
  final int? statusCode;
}

/// Accepts `XXXX-XXXX-XXXX` (letters/digits). Returns minimal JSON compatible with [flutter_v2ray] parser.
class StubLicenseRepository implements LicenseRepository {
  static final _keyPattern = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');

  static String stubV2RayJson({
    required String deviceId,
    required DateTime expiresAt,
  }) {
    return jsonEncode({
      'remark': 'NovaNet stub',
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': 10808,
          'protocol': 'socks',
          'settings': {'udp': true},
        },
      ],
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': '127.0.0.1',
                'port': '443',
                'users': [
                  {
                    'encryption': 'none',
                    'id': '00000000-0000-0000-0000-000000000001',
                  },
                ],
              },
            ],
          },
          'streamSettings': {'network': 'tcp', 'security': 'none'},
          'tag': 'proxy',
        },
        {'protocol': 'freedom', 'tag': 'direct', 'settings': {}},
      ],
      'metadata': {
        'deviceBinding': deviceId,
        'expiresAt': expiresAt.toIso8601String(),
      },
    });
  }

  @override
  Future<LicenseActivationResult> activate({
    required String formattedKey,
    required String deviceId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!_keyPattern.hasMatch(formattedKey.trim().toUpperCase())) {
      return const LicenseActivationFailure(
        'Enter a valid license key in XXXX-XXXX-XXXX format.',
      );
    }
    final expiresAt = DateTime.now().add(const Duration(days: 30));
    final stubConfig = stubV2RayJson(deviceId: deviceId, expiresAt: expiresAt);
    return LicenseActivated(v2RayConfigJson: stubConfig, expiresAt: expiresAt);
  }
}
