import 'dart:async';

import '../domain/vpn_connection_state.dart';

/// Abstraction over `flutter_v2ray` / platform VPN service.
abstract class VpnRepository {
  Future<void> start(String v2RayConfigJson);
  Future<void> stop();
  VpnConnectionState get currentState;

  /// Emits whenever [currentState] changes (native bridge should push updates).
  Stream<VpnConnectionState> get states;

  /// Release native resources / streams (called from [VpnSessionController.dispose]).
  void dispose() {}
}

/// Optional diagnostics capability for native VPN adapters.
abstract class VpnDiagnosticsCapable {
  String buildVpnDebugReport();
}

/// Dev implementation: simulates latency and state transitions.
class StubVpnRepository implements VpnRepository, VpnDiagnosticsCapable {
  StubVpnRepository() {
    _emit(_state);
  }

  final _states = StreamController<VpnConnectionState>.broadcast();
  VpnConnectionState _state = VpnConnectionState.idle;
  bool _disposed = false;
  final List<String> _debugEvents = <String>[];

  void _log(String msg) {
    _debugEvents.add('${DateTime.now().toIso8601String()} $msg');
    if (_debugEvents.length > 200) {
      _debugEvents.removeRange(0, _debugEvents.length - 200);
    }
  }

  void _emit(VpnConnectionState next) {
    _state = next;
    _log('state=$next');
    if (!_states.isClosed) _states.add(next);
  }

  @override
  VpnConnectionState get currentState => _state;

  @override
  Stream<VpnConnectionState> get states => _states.stream;

  @override
  Future<void> start(String v2RayConfigJson) async {
    _log('start called configBytes=${v2RayConfigJson.length}');
    _emit(VpnConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (v2RayConfigJson.isEmpty) {
      _emit(VpnConnectionState.error);
      return;
    }
    _emit(VpnConnectionState.connected);
  }

  @override
  Future<void> stop() async {
    _log('stop called');
    _emit(VpnConnectionState.disconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _emit(VpnConnectionState.idle);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _states.close();
  }

  @override
  String buildVpnDebugReport() {
    final lines = <String>[
      'repository=StubVpnRepository',
      'currentState=$_state',
      'recentEvents:',
      ..._debugEvents.map((e) => '  $e'),
    ];
    return lines.join('\n');
  }
}
