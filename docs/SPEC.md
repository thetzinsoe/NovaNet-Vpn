# Technical specification

## V2Ray on device

- **Target plugin:** `flutter_v2ray` (or project-chosen equivalent).
- **Flow:**
  1. Initialize V2Ray core when appropriate (app start or first connect — follow plugin guidance).
  2. On Connect, ensure a valid license and obtain config (cache or `activateVpnKey`).
  3. Accept either full V2Ray JSON or a supported share link such as `vless://...`.
  4. Convert share links with `FlutterV2ray.parseFromURL(...).getFullConfiguration()`.
  5. Pass the resulting V2Ray JSON into the native `start` API.
  6. Mirror native connection state into `VpnRepository.states`.

## Firebase (reference schema)

- **Collection:** `license_keys`
- **Suggested fields:** `key` (string), `plan_days` (int), `is_used` (bool), `expires_at` (timestamp), `device_id` (string).

**Cloud Function `activateVpnKey`:** validate key exists, not expired, and `device_id` matches stored binding (per product rules). Return signed config on success.

Current Rowy/Firestore server config shape:

- `config/main_server/vless_link`: real VLESS share link returned by the callable.

## Local cache (client)

- **V2Ray JSON** is stored with **`flutter_secure_storage`** (`SecureLicenseConfigStorage`), not plain `SharedPreferences`. Expiry remains in `SharedPreferences` as ISO string `novanet_license_expires_iso`.
- One-time migration reads legacy `novanet_v2ray_config_cache` from prefs, writes secure storage, and removes the old key.

## Stub behavior (this repo)

- **`StubLicenseRepository`:** accepts alphanumeric pattern `XXXX-XXXX-XXXX`; returns a **minimal valid** Xray JSON (inbounds/outbounds) for `flutter_v2ray` parser tests and 30-day expiry.
- **`StubVpnRepository`:** simulates connect/disconnect delays and emits `states` for UI.
- By default, `flutter run` uses `StubVpnRepository`. Enable real device VPN only with `--dart-define=NOVANET_USE_NATIVE_VPN=true` and a real backend-provided V2Ray config.

Replace stubs without renaming `VpnSessionController` public API where possible.
