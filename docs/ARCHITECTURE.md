# NovaNet system architecture

## Client (Flutter)

The app is organized by **feature** under `lib/features/`, with shared UI tokens under `lib/core/` and composition under `lib/app/`.

- **`VpnSessionController`** (`ChangeNotifier`): reads/writes license cache in `SharedPreferences`, calls `LicenseRepository` for activation, and `VpnRepository` for start/stop. The UI watches this controller via `provider`.
- **`VpnRepository`**: abstraction over the native tunnel (`flutter_v2ray` or equivalent). Production implementations should expose `currentState` and a `states` stream aligned with the OS VPN service.
- **`LicenseRepository`**: abstraction over `activateVpnKey`. Production implementation calls a Firebase callable and maps success/failure to `LicenseActivationResult`.

## Backend (planned)

### License key flow

1. User enters a 12-character alphanumeric key formatted as `XXXX-XXXX-XXXX`.
2. Client calls Cloud Function `activateVpnKey(key, deviceId)`.
3. Function validates Firestore collection `license_keys`.
4. On success, returns a signed **V2Ray JSON config** string (or URL) for the client core.

### Connection lifecycle (UI)

| State | Meaning |
|-------|---------|
| Idle | Not tunneling; user can connect if licensed. |
| Connecting | Validating or bringing up native VPN. |
| Connected | Traffic routed through NovaNet. |
| Disconnecting | Tearing down tunnel. |
| Error | Recoverable failure; user may retry. |

Separate from tunnel state: **license expired** — UI blocks connect and prompts renewal.

### Server management

- Server definitions managed operationally (e.g. Rowy).
- Collection `v2ray_configs` (or equivalent) holds config payloads.
- Rotation: Cloud Function returns updated config for eligible keys.

See [SPEC.md](SPEC.md) for field-level Firestore notes.
