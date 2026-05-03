/// Result of calling `activateVpnKey` (Firebase) — stub uses the same shape.
sealed class LicenseActivationResult {
  const LicenseActivationResult();
}

final class LicenseActivated extends LicenseActivationResult {
  const LicenseActivated({
    required this.v2RayConfigJson,
    required this.expiresAt,
  });

  /// Raw config string passed to `flutter_v2ray` / native core.
  final String v2RayConfigJson;
  final DateTime expiresAt;
}

final class LicenseActivationFailure extends LicenseActivationResult {
  const LicenseActivationFailure(this.message);
  final String message;
}
