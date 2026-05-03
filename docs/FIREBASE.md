# Firebase: license activation

## Callable: `activateVpnKey`

**Request body (JSON):**

| Field | Type | Description |
|-------|------|-------------|
| `key` | string | User key in alphanumeric `XXXX-XXXX-XXXX` form (normalize uppercase server-side). |
| `deviceId` | string | Client install ID from the app. |

**Success response (map):**

| Field | Type | Description |
|-------|------|-------------|
| `v2RayConfigJson` | string | Full Xray/V2Ray JSON config, or a supported share link such as `vless://...`. The app converts links with `FlutterV2ray.parseFromURL`. |
| `expiresAt` | string (ISO 8601) or Timestamp | License expiry. |

Aliases accepted: `config` instead of `v2RayConfigJson`, `expires_at` instead of `expiresAt`.

## Firestore (suggested)

Collection **`license_keys`** (managed via Rowy or console):

- `key` (string)
- `plan_days` (number)
- `is_used` (boolean)
- `expires_at` (timestamp)
- `device_id` (string, bound after first activation)

Server logic should validate key, expiry, and device binding before returning config. **Do not** embed raw server IPs in the client; return them only inside the signed or server-generated JSON config.

Server config currently reads from:

- Collection: `config`
- Document: `main_server`
- Field: `vless_link`

### `vless_link` validation rules (backend)

`activateVpnKey` validates `config/main_server.vless_link` before returning it:

- Must be a valid `vless://` URL
- Must include host and user id
- If `security=tls`: must include either `sni` or `host`
- If `security=reality`: must include `sni`, `fp`, and `pbk`

If validation fails, backend returns `failed-precondition` so clients fail fast with actionable diagnostics.

The callable returns that field as `v2RayConfigJson`; the app converts the VLESS link to JSON before starting `flutter_v2ray`.

## Flutter client

- Enable with `--dart-define=NOVANET_USE_FIREBASE=true`.
- Run `flutterfire configure` and replace placeholder values in [`lib/firebase_options.dart`](../lib/firebase_options.dart).
- Add platform files: `google-services.json` (Android), `GoogleService-Info.plist` (iOS).

## Sample Cloud Function

See [`functions/`](../functions/) for a minimal `activateVpnKey` implementation.

## HTTP fallback endpoint

When callable transport is unavailable on some device/network combinations, the app
falls back to:

- `POST https://us-central1-<project-id>.cloudfunctions.net/activateVpnKeyHttp`

Request body is the same `{ key, deviceId }`, and response shape is the same as the
callable success response.

### Optional runtime overrides

You can control fallback behavior from Flutter compile-time flags:

- `NOVANET_FUNCTION_REGIONS` (default `us-central1`)
  - Comma-separated region priority for generated HTTP fallback URLs.
  - Default in this app: `us-central1,asia-southeast1`
- Cloud Functions are configured for both regions in `functions/index.js` via:
  - `functions.region("us-central1", "asia-southeast1")`
- `NOVANET_FUNCTION_HTTP_URLS` (default empty)
  - Comma-separated explicit `activateVpnKeyHttp` URLs.
  - When set, this list is used instead of generated region URLs.
