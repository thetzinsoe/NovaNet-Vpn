# NovaNet System Architecture

## 1. The License Key Flow
1. User enters 12-digit key (XXXX-XXXX-XXXX).
2. Flutter calls Firebase Cloud Function `activateVpnKey(key, deviceId)`.
3. Firebase checks Firestore `license_keys` collection.
4. If valid, Firebase returns a signed V2Ray JSON config.

## 2. The Connection Lifecycle
- **IDLE:** App waits for User to press the Power Button.
- **CONNECTING:** App validates the local `shared_preferences` key with the backend.
- **CONNECTED:** `flutter_v2ray` starts the native VpnService.
- **EXPIRED:** App restricts access and shows a "Renew" modal.

## 3. Server Management
- Servers are managed in Rowy.
- The `v2ray_configs` collection contains the raw strings.
- Rotation is handled by updating the Cloud Function return value.