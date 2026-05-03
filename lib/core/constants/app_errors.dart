/// User-facing messages mapped from Firebase / native failures.
abstract final class AppErrors {
  static const invalidKey = 'Invalid license key. Check and try again.';
  static const deviceMismatch = 'This key is bound to another device.';
  static const serverBusy = 'Servers are busy. Try again in a moment.';
  static const activationTransportBlocked =
      'Cannot reach activation service from this network/device. Try another network or disable private DNS/proxy/VPN.';
  static const network = 'Network error. Check your connection.';
  static const activationFailed = 'Activation failed. Please try again.';
  static const vpnPermissionDenied = 'VPN permission is required to connect.';
  static const vpnStartFailed = 'Could not start the VPN tunnel.';
  static const vpnStartTimeout =
      'VPN start timed out. Check the server config.';
  static const vpnServerUnreachable =
      'VPN server is unreachable or configuration is invalid.';
  static const vpnNotSupported = 'VPN is only available on Android and iOS.';
}
