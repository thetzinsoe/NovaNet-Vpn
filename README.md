# NovaNet VPN

Cross-platform **Flutter** client for a license-key–activated VPN using **V2Ray** on Android/iOS ([`flutter_v2ray`](https://pub.dev/packages/flutter_v2ray)), **Firebase Cloud Functions** for activation, and **secure storage** for cached tunnel config. The UI uses the **Sea Blue (#006994) and white** brand theme (`AppTheme.nova()`).

## Features (current)

- Home screen with connection state, `RepaintBoundary` around the power control, and license / expiry UI.
- License screen with `LicenseKeyInputFormatter` (`XXXX-XXXX-XXXX`) and device install ID.
- **Android / iOS:** `FlutterV2rayVpnRepository` (real VPN) when `NOVANET_USE_NATIVE_VPN=true`.
- **Default dev/CI:** `StubVpnRepository`, so local license tests can connect without a real V2Ray server.
- **Firebase:** `FirebaseLicenseRepository` when `NOVANET_USE_FIREBASE=true` and `firebase_options.dart` is configured.
- **Config cache:** `flutter_secure_storage` (with one-time migration from legacy SharedPreferences).

## Compile-time flags

| Define | Default | Effect |
|--------|---------|--------|
| `NOVANET_USE_FIREBASE` | `false` | Use `StubLicenseRepository` vs `FirebaseLicenseRepository` + `Firebase.initializeApp`. |
| `NOVANET_USE_NATIVE_VPN` | `false` | On Android/iOS only: real V2Ray vs stub. |
| `NOVANET_FUNCTION_REGIONS` | `us-central1,asia-southeast1` | Comma-separated region priority for generated HTTP fallback endpoints. |
| `NOVANET_FUNCTION_HTTP_URLS` | _(empty)_ | Optional comma-separated explicit `activateVpnKeyHttp` URLs (overrides generated region URLs). |

Example:

```bash
flutter run --dart-define=NOVANET_USE_FIREBASE=true
```

When callable transport is blocked by a device/network, force alternate HTTP fallback
endpoints:

```bash
flutter run \
  --dart-define=NOVANET_USE_FIREBASE=true \
  --dart-define=NOVANET_FUNCTION_REGIONS=us-central1,asia-southeast1 \
  --dart-define=NOVANET_FUNCTION_HTTP_URLS=https://us-central1-novanet-vpn.cloudfunctions.net/activateVpnKeyHttp,https://asia-southeast1-novanet-vpn.cloudfunctions.net/activateVpnKeyHttp
```

To test the real native tunnel, use both a real backend config and native VPN:

```bash
flutter run --dart-define=NOVANET_USE_FIREBASE=true --dart-define=NOVANET_USE_NATIVE_VPN=true
```

See [docs/FIREBASE.md](docs/FIREBASE.md) and [functions/](functions/) for the `activateVpnKey` callable.

## Project layout

| Path | Role |
|------|------|
| `lib/app/` | `MaterialApp`, routes, `nova_providers.dart` (DI with `provider`). |
| `lib/core/` | Config flags, theme, strings, errors, storage. |
| `lib/features/vpn/` | `VpnSessionController`, `VpnRepository`, `flutter_v2ray` adapter, UI. |
| `lib/features/license/` | `LicenseRepository` (stub + Firebase), license UI, input formatter. |
| `docs/` | Architecture, spec, Firebase notes. |
| `functions/` | Sample Node.js `activateVpnKey` implementation. |
| `.github/workflows/` | `flutter analyze`, `test`, `dart format` check. |

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK matches `pubspec.yaml` `environment.sdk`).
- Android Studio / Xcode for mobile; run **FlutterFire** when using Firebase: `flutterfire configure` and replace placeholders in `lib/firebase_options.dart`.

## Run

```bash
flutter pub get
flutter run
```

## Tests & CI

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
```

## Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/SPEC.md](docs/SPEC.md)
- [docs/FIREBASE.md](docs/FIREBASE.md)
- [docs/LLM_IMPROVEMENT_HANDOFF.md](docs/LLM_IMPROVEMENT_HANDOFF.md)

## Cursor

- **Rule:** `.cursor/rules/novanet-vpn-flutter.mdc`
- **Skill:** `.cursor/skills/novanet-vpn-app/SKILL.md`

## License

Private / unpublished (`publish_to: 'none'` in `pubspec.yaml`). Adjust as needed.
