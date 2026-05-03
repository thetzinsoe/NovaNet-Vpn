---
name: novanet-vpn-app
description: Extends the NovaNet VPN app — Flutter V2Ray tunnel (flutter_v2ray), Firebase callable activation, secure config storage, and Provider wiring. Use when changing VPN connect flow, Cloud Function contracts, LicenseRepository/VpnRepository implementations, Android VPN permissions, iOS Network Extension setup, VpnSessionController, or Rowy/Firestore license schema.
---

# NovaNet VPN app development

## Read first

- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) — client vs backend responsibilities.
- [docs/SPEC.md](../../../docs/SPEC.md) — V2Ray + Firebase reference.
- [docs/FIREBASE.md](../../../docs/FIREBASE.md) — `activateVpnKey` contract.

## Wiring (implemented)

- **Flags:** `AppConfig` (`lib/core/config/app_config.dart`) reads `--dart-define=NOVANET_USE_FIREBASE` and `NOVANET_USE_NATIVE_VPN`. Repositories are resolved in `nova_providers.dart`.
- **VPN:** `FlutterV2rayVpnRepository` (IO) vs `StubVpnRepository`; dispose via `VpnRepository.dispose()` from `VpnSessionController.dispose`.
- **License:** `FirebaseLicenseRepository` vs `StubLicenseRepository`.
- **Config at rest:** `SecureLicenseConfigStorage` (`flutter_secure_storage`); expiry ISO remains in `SharedPreferences`.

## Implementation checklist

1. **Native bridge:** Map `V2RayStatus.state` strings (`V2RAY_*`) into `VpnConnectionState` in `flutter_v2ray_vpn_repository_io.dart` if the plugin adds new states.
2. **Callable response:** Keep `{ v2RayConfigJson, expiresAt }` shape or extend `FirebaseLicenseRepository._mapSuccess` with aliases.
3. **Theme:** Sea blue / white lives in `AppTheme.nova()` — keep new screens consistent.

## Constraints

- Do not call platform VPN or Firebase from `presentation/` widgets — use `VpnSessionController` or repositories.
- Preserve `LicenseActivationResult` and `VpnConnectionState` unless migrating all call sites.

## Verification

Run `flutter analyze` and `flutter test`. Exercise connect/disconnect on a physical Android/iOS device when changing `flutter_v2ray` integration.
