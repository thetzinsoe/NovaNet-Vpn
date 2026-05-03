import 'package:flutter/foundation.dart';

/// Compile-time flags — pass via `--dart-define`.
abstract final class AppConfig {
  static const useFirebase = bool.fromEnvironment(
    'NOVANET_USE_FIREBASE',
    defaultValue: false,
  );

  /// When false, uses [StubVpnRepository] (default dev/CI behavior).
  ///
  /// Enable only when the license backend returns a real V2Ray config:
  /// `--dart-define=NOVANET_USE_NATIVE_VPN=true`.
  static const useNativeVpn = bool.fromEnvironment(
    'NOVANET_USE_NATIVE_VPN',
    defaultValue: false,
  );

  static bool get shouldUseFirebase => useFirebase && !kIsWeb;

  static bool get shouldUseNativeVpn =>
      useNativeVpn &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Comma-separated Cloud Functions regions, first is primary.
  /// Example: `--dart-define=NOVANET_FUNCTION_REGIONS=us-central1,asia-southeast1`
  static const functionRegionsCsv = String.fromEnvironment(
    'NOVANET_FUNCTION_REGIONS',
    defaultValue: 'us-central1,asia-southeast1',
  );

  /// Optional explicit HTTP fallback URL list (comma-separated).
  /// Example:
  /// `--dart-define=NOVANET_FUNCTION_HTTP_URLS=https://.../activateVpnKeyHttp,https://.../activateVpnKeyHttp`
  static const functionHttpUrlsCsv = String.fromEnvironment(
    'NOVANET_FUNCTION_HTTP_URLS',
    defaultValue: '',
  );
}
