# Technical Specification

## V2Ray Implementation
- **Plugin:** `flutter_v2ray`
- **Logic:** 1. App initializes V2Ray core on boot.
  2. On 'Connect', app calls Firebase Function `activateVpnKey`.
  3. Firebase returns a VLESS/VMESS configuration string.
  4. App passes this string to `startV2Ray`.

## Firebase Logic
- **Collection:** `license_keys`
- **Fields:** `key` (String), `plan_days` (Int), `is_used` (Bool), `expires_at` (Timestamp), `device_id` (String).
- **Cloud Function:** Must validate the key exists, isn't expired, and matches the stored `device_id`.