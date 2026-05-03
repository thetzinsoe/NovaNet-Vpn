# NovaNet VPN Context Handoff (Compact)

Use this file to restore context after chat reset.

## Why context was reset

- The chat became very long with repeated Android runtime noise logs (`gralloc4`, MIUI rendering, Google Play internals), making it hard to keep high-signal context.
- This compact handoff preserves only decisions, current behavior, and next steps.

## Goal

Build a Flutter VPN app where:

1. User enters activation key.
2. Backend validates key + device binding.
3. Backend returns VLESS/V2Ray payload.
4. App converts to full V2Ray config and starts native tunnel via `flutter_v2ray`.

## Previous chat history (condensed)

- Flutter app architecture and provider wiring are in place (`license`, `vpn`, `core`, `app`).
- License format changed to alphanumeric `XXXX-XXXX-XXXX`.
- Firebase callable activation implemented with HTTP fallback.
- Backend reads `config/main_server/vless_link` with legacy fallback.
- `activateVpnKey` and `activateVpnKeyHttp` deployed and working.
- Device had callable transport issues (`GoogleApiManager`, `DEVELOPER_ERROR`, `unavailable`).
- Multi-region rollout completed:
  - `us-central1`
  - `asia-southeast1`
- App fallback now supports region list + explicit HTTP URL overrides.

## Current chat history (condensed)

- Added activation transport diagnostics in app (callable + HTTP per-endpoint checks).
- Confirmed from device diagnostics:
  - `us-central1` often reset/blocked
  - `asia-southeast1` reachable
- Confirmed from function logs that real activation returns HTTP `200`.
- Added stricter VPN startup watchdog/timeouts to avoid endless `Connecting...`.
- Added built-in debug report system (copyable from app UI via bug icon).
- Found and fixed critical state parsing bug:
  - `DISCONNECTED` was incorrectly interpreted as `CONNECTED` due to substring matching.
  - Parser now uses token-based exact matching.

## Current status

- Activation: working (license validates and config is returned).
- Tunnel state UX: improved; false-positive `connected` bug fixed in code.
- Remaining real-world check: verify Android system VPN icon and actual traffic tunnel behavior after latest parser fix.

## Key files to continue from

- `lib/features/license/data/firebase_license_repository.dart`
- `lib/features/vpn/data/flutter_v2ray_vpn_repository_io.dart`
- `lib/features/vpn/application/vpn_session_controller.dart`
- `lib/features/vpn/presentation/home_screen.dart`
- `lib/core/config/app_config.dart`
- `functions/index.js`
- `docs/FIREBASE.md`

## Run / verify commands

```bash
flutter run --dart-define=NOVANET_USE_FIREBASE=true --dart-define=NOVANET_USE_NATIVE_VPN=true
```

```bash
firebase functions:list --project novanet-vpn
firebase functions:log --only activateVpnKeyHttp --project novanet-vpn --lines 80
```

## Next step after reset

1. Run app on device.
2. Attempt activation + connect.
3. Open bug icon in app, copy debug report.
4. Verify:
   - `nativeStatus` transitions
   - final `tunnelState`
   - whether Android VPN key icon appears.
