import 'dart:async';
import 'dart:convert';

import 'package:flutter_v2ray/flutter_v2ray.dart';

import '../../../core/constants/app_errors.dart';
import '../domain/vpn_connection_state.dart';
import 'vpn_repository.dart';

/// Android / iOS VPN via [flutter_v2ray]. Status comes from native events.
class FlutterV2rayVpnRepository
    implements VpnRepository, VpnDiagnosticsCapable {
  FlutterV2rayVpnRepository() {
    _v2ray = FlutterV2ray(onStatusChanged: _handleStatus);
    _emit(VpnConnectionState.idle);
  }

  late final FlutterV2ray _v2ray;
  final StreamController<VpnConnectionState> _states =
      StreamController<VpnConnectionState>.broadcast();

  VpnConnectionState _state = VpnConnectionState.idle;
  bool _initialized = false;
  bool _startInFlight = false;
  Completer<VpnConnectionState>? _pendingStartState;
  final List<String> _debugEvents = <String>[];
  String _lastRawStatus = 'unknown';

  static const _startInvokeTimeout = Duration(seconds: 20);
  static const _startStateTimeout = Duration(seconds: 25);
  static const _delayProbeTimeout = Duration(seconds: 8);
  static const _delayProbeUrls = <String>[
    'https://www.gstatic.com/generate_204',
    'https://cp.cloudflare.com/generate_204',
    'https://connectivitycheck.gstatic.com/generate_204',
  ];

  void _log(String msg) {
    _debugEvents.add('${DateTime.now().toIso8601String()} $msg');
    if (_debugEvents.length > 300) {
      _debugEvents.removeRange(0, _debugEvents.length - 300);
    }
  }

  void _emit(VpnConnectionState next) {
    _state = next;
    _log('state=$next');
    if (!_states.isClosed) _states.add(next);
  }

  void _handleStatus(V2RayStatus status) {
    _lastRawStatus = status.state;
    _log(
      'nativeStatus=${status.state} duration=${status.duration} up=${status.upload} down=${status.download} upSpeed=${status.uploadSpeed} downSpeed=${status.downloadSpeed}',
    );
    final next = _mapState(status.state);
    final hasPendingStart =
        _pendingStartState != null && !_pendingStartState!.isCompleted;
    // Some devices/plugins keep emitting CONNECTING after a failed/aborted start.
    // Ignore those stale transitional statuses when no start is in flight.
    if (next == VpnConnectionState.connecting &&
        !_startInFlight &&
        !hasPendingStart &&
        (_state == VpnConnectionState.error ||
            _state == VpnConnectionState.idle ||
            _state == VpnConnectionState.disconnecting)) {
      _log('ignore stale connecting status');
      return;
    }
    _emit(next);
    final pending = _pendingStartState;
    if (pending != null &&
        !pending.isCompleted &&
        (next == VpnConnectionState.connected ||
            next == VpnConnectionState.error ||
            next == VpnConnectionState.idle)) {
      pending.complete(next);
    }
  }

  VpnConnectionState _mapState(String raw) {
    final s = raw.toUpperCase();
    final tokens = s
        .split(RegExp(r'[^A-Z]+'))
        .where((t) => t.isNotEmpty)
        .toSet();
    if (tokens.contains('DISCONNECTED') ||
        tokens.contains('DISCONNECT') ||
        tokens.contains('STOPPED') ||
        tokens.contains('IDLE')) {
      return VpnConnectionState.idle;
    }
    if (tokens.contains('ERROR') ||
        tokens.contains('FAILED') ||
        tokens.contains('FAIL')) {
      return VpnConnectionState.error;
    }
    // Be strict: only explicit CONNECTED means tunnel is established.
    if (tokens.contains('CONNECTED')) return VpnConnectionState.connected;
    // STARTED/RUNNING/CONNECTING may mean process up but not yet fully tunneled.
    if (tokens.contains('CONNECTING') ||
        tokens.contains('RUNNING') ||
        tokens.contains('STARTED')) {
      return VpnConnectionState.connecting;
    }
    return _state;
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _log('initializeV2Ray start');
    await _v2ray.initializeV2Ray();
    _initialized = true;
    _log('initializeV2Ray ok');
  }

  static String _readRemark(String configJson) {
    if (configJson.trim().contains('://')) {
      try {
        final remark = FlutterV2ray.parseFromURL(configJson.trim()).remark;
        if (remark.isNotEmpty) return remark;
      } catch (_) {}
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final r = m['remark'];
      if (r is String && r.isNotEmpty) return r;
    } catch (_) {}
    return 'NovaNet VPN';
  }

  static String _normalizeConfig(String rawConfig) {
    final trimmed = rawConfig.trim();
    if (trimmed.contains('://')) {
      return FlutterV2ray.parseFromURL(trimmed).getFullConfiguration();
    }
    return trimmed;
  }

  static String? _extractServerEndpoint(String configJson) {
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final outbounds = m['outbounds'];
      if (outbounds is! List || outbounds.isEmpty) return null;
      final first = outbounds.first;
      if (first is! Map) return null;
      final settingsRaw = first['settings'];
      if (settingsRaw is! Map) return null;
      final settings = Map<String, dynamic>.from(settingsRaw);

      final vnextRaw = settings['vnext'];
      if (vnextRaw is List && vnextRaw.isNotEmpty) {
        final node = vnextRaw.first;
        if (node is Map) {
          final host = node['address'];
          final port = node['port'];
          if (host is String && host.isNotEmpty) {
            return '$host:$port';
          }
        }
      }

      final serversRaw = settings['servers'];
      if (serversRaw is List && serversRaw.isNotEmpty) {
        final node = serversRaw.first;
        if (node is Map) {
          final host = node['address'];
          final port = node['port'];
          if (host is String && host.isNotEmpty) {
            return '$host:$port';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _logRawConfigHints(String rawConfig) {
    final trimmed = rawConfig.trim();
    if (!trimmed.contains('://')) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      _log('rawLink parse failed');
      return;
    }
    final security = (uri.queryParameters['security'] ?? '').trim();
    final sni = (uri.queryParameters['sni'] ?? '').trim();
    final host = (uri.queryParameters['host'] ?? '').trim();
    final fp = (uri.queryParameters['fp'] ?? '').trim();
    final pbk = (uri.queryParameters['pbk'] ?? '').trim();
    final sid = (uri.queryParameters['sid'] ?? '').trim();
    _log(
      'rawLink scheme=${uri.scheme} host=${uri.host} port=${uri.hasPort ? uri.port : 'default'} security=$security sni=${sni.isEmpty ? '-' : sni} hostParam=${host.isEmpty ? '-' : host} fp=${fp.isEmpty ? '-' : fp} pbk=${pbk.isEmpty ? 'missing' : 'present'} sid=${sid.isEmpty ? 'missing' : 'present'}',
    );
    if ((security == 'tls' || security == 'reality') &&
        sni.isEmpty &&
        host.isEmpty) {
      _log('rawLink warning: tls/reality without sni/host');
    }
    if (security == 'reality' && pbk.isEmpty) {
      _log('rawLink warning: reality without pbk');
    }
  }

  Future<bool> _runDelayPreflight(String config) async {
    var anyReachable = false;
    for (final url in _delayProbeUrls) {
      try {
        final delay = await _v2ray
            .getServerDelay(config: config, url: url)
            .timeout(_delayProbeTimeout);
        _log('preflightServerDelayMs[$url]=$delay');
        if (delay > 0) {
          anyReachable = true;
        }
      } on TimeoutException {
        _log('preflightServerDelay timeout [$url]');
      } catch (e) {
        _log('preflightServerDelay error [$url]=$e');
      }
    }
    return anyReachable;
  }

  @override
  VpnConnectionState get currentState => _state;

  @override
  Stream<VpnConnectionState> get states => _states.stream;

  @override
  Future<void> start(String v2RayConfigJson) async {
    await _ensureInit();
    _startInFlight = true;
    _emit(VpnConnectionState.connecting);
    _log('requestPermission start');
    final permitted = await _v2ray.requestPermission();
    _log('requestPermission result=$permitted');
    if (!permitted) {
      _startInFlight = false;
      _emit(VpnConnectionState.error);
      throw StateError(AppErrors.vpnPermissionDenied);
    }
    final pending = Completer<VpnConnectionState>();
    _pendingStartState = pending;
    var preflightReachable = true;
    try {
      _logRawConfigHints(v2RayConfigJson);
      final config = _normalizeConfig(v2RayConfigJson);
      final endpoint = _extractServerEndpoint(config);
      if (endpoint != null) {
        _log('parsedServerEndpoint=$endpoint');
      }
      preflightReachable = await _runDelayPreflight(config);
      if (!preflightReachable) {
        _log('preflight failed: endpoint unreachable before start');
        _emit(VpnConnectionState.error);
        throw StateError(AppErrors.vpnServerUnreachable);
      }
      _log('startV2Ray invoke configBytes=${config.length}');
      await _v2ray
          .startV2Ray(
            remark: _readRemark(v2RayConfigJson),
            config: config,
            blockedApps: null,
            bypassSubnets: null,
            proxyOnly: false,
          )
          .timeout(_startInvokeTimeout);
      _log('startV2Ray invoke completed');
      if (_state == VpnConnectionState.connected) return;
      final settled = await pending.future.timeout(_startStateTimeout);
      _log('start settle result=$settled');
      if (settled != VpnConnectionState.connected) {
        _emit(VpnConnectionState.error);
        throw StateError(
          preflightReachable
              ? AppErrors.vpnStartFailed
              : AppErrors.vpnServerUnreachable,
        );
      }
    } on TimeoutException {
      _log('start timeout');
      unawaited(_v2ray.stopV2Ray());
      _emit(VpnConnectionState.error);
      throw StateError(
        preflightReachable
            ? AppErrors.vpnStartTimeout
            : AppErrors.vpnServerUnreachable,
      );
    } catch (e) {
      _log('start error=$e');
      if (_state != VpnConnectionState.error) {
        _emit(VpnConnectionState.error);
      }
      if (e is StateError) rethrow;
      throw StateError(AppErrors.vpnStartFailed);
    } finally {
      _startInFlight = false;
      if (identical(_pendingStartState, pending)) {
        _pendingStartState = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    _log('stopV2Ray invoke');
    _emit(VpnConnectionState.disconnecting);
    await _v2ray.stopV2Ray();
    _log('stopV2Ray completed');
  }

  @override
  void dispose() {
    _states.close();
  }

  @override
  String buildVpnDebugReport() {
    final lines = <String>[
      'repository=FlutterV2rayVpnRepository',
      'initialized=$_initialized',
      'currentState=$_state',
      'lastRawStatus=$_lastRawStatus',
      'recentEvents:',
      ..._debugEvents.map((e) => '  $e'),
    ];
    return lines.join('\n');
  }
}
