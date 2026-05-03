# NovaNet VPN LLM improvement handoff

This document is written for future LLM/Cursor sessions. It summarizes the current project, the intended product flow, and the safest improvement direction for UI, logic, and folder structure.

## Current project snapshot

NovaNet VPN is a Flutter mobile VPN client with:

- Feature-first folders under `lib/features/`.
- `Provider`-based dependency injection in `lib/app/nova_providers.dart`.
- A license flow behind `LicenseRepository`.
- A tunnel flow behind `VpnRepository`.
- Compile-time flags in `AppConfig`:
  - `NOVANET_USE_FIREBASE=true` enables `FirebaseLicenseRepository`.
  - `NOVANET_USE_NATIVE_VPN=true` enables `FlutterV2rayVpnRepository` on Android/iOS.
- Secure V2Ray config storage through `LicenseConfigStorage` / `SecureLicenseConfigStorage`.
- A Sea Blue and White brand theme in `AppTheme.nova()` and `AppColors`.
- Tests for the widget shell, license key formatter, and `VpnSessionController`.

Do not bypass these existing boundaries unless a later refactor deliberately replaces the architecture.

## Existing flow

### App startup

1. `main.dart` initializes Flutter bindings.
2. If Firebase is enabled and the current platform is not web, `Firebase.initializeApp()` runs with `DefaultFirebaseOptions`.
3. `SharedPreferences` is loaded.
4. `SecureLicenseConfigStorage` reads the cached V2Ray JSON config from secure storage, with one-time migration from the legacy SharedPreferences key.
5. `novaProvidersApp()` builds repositories, device ID, storage, and `VpnSessionController`.
6. `NovaApp` starts at `HomeScreen`.

### License activation

1. User enters a 12-character alphanumeric key on `LicenseScreen`.
2. `LicenseKeyInputFormatter` formats it as `XXXX-XXXX-XXXX`.
3. `LicenseScreen` calls `VpnSessionController.activateLicense()`.
4. The controller calls `LicenseRepository.activate(formattedKey, deviceId)`.
5. Stub mode accepts any valid pattern and returns a local V2Ray JSON stub.
6. Firebase mode calls the `activateVpnKey` callable and expects `{ v2RayConfigJson, expiresAt }`.
7. On success, config is written to secure storage, config is cached in memory, and expiry is saved in SharedPreferences.

### VPN connect/disconnect

1. `HomeScreen` watches `VpnSessionController`.
2. Connect is allowed only when `hasActiveLicense` is true and cached config exists.
3. `VpnSessionController.connect()` passes the V2Ray JSON to `VpnRepository.start()`.
4. Stub mode simulates `connecting -> connected`.
5. Native mode requests VPN permission, calls `flutter_v2ray.startV2Ray()`, and maps plugin status updates into `VpnConnectionState`.
6. `VpnSessionController` listens to `VpnRepository.states` and notifies the UI.

## What is good already

- Repository boundaries are in the right place: no Firebase or native VPN calls from widgets.
- `VpnSessionController` acts as a single orchestration point.
- Secure storage is already used for sensitive V2Ray config.
- Runtime selection between stub/real implementations makes CI and desktop development easier.
- Cursor rule and skill files match the project architecture.
- Tests cover several important seams: formatting, controller activation/connect, and app shell.

## Main improvement goals

The next work should improve the app without flattening the existing architecture. Prioritize:

1. UI polish and reusable design widgets.
2. More explicit session/domain state.
3. Better repository error mapping and native status coverage.
4. A slightly clearer folder layout as the app grows.
5. Stronger tests around real product behavior.

## Recommended folder structure

Keep the current structure, but add subfolders only when the current files grow.

```text
lib/
  app/
    nova_app.dart
    nova_providers.dart
    app_routes.dart              # Add when routes grow beyond two screens.
  core/
    config/
      app_config.dart
    constants/
      app_errors.dart
      app_strings.dart
    design/
      nova_spacing.dart          # Add reusable spacing/radius/elevation tokens.
      nova_shadows.dart          # Optional, only if repeated.
    services/
      device_id_service.dart
    storage/
      license_config_storage.dart
    theme/
      app_colors.dart
      app_theme.dart
  features/
    license/
      application/
        license_controller.dart  # Add only if license screen logic grows.
      data/
        firebase_license_repository.dart
        license_repository.dart
      domain/
        license_activation.dart
        license_state.dart       # Recommended next addition.
      presentation/
        license_screen.dart
        license_key_input_formatter.dart
        widgets/                 # Add for reusable license widgets.
    vpn/
      application/
        vpn_session_controller.dart
      data/
        flutter_v2ray_vpn_repository.dart
        flutter_v2ray_vpn_repository_io.dart
        flutter_v2ray_vpn_repository_stub.dart
        vpn_repository.dart
      domain/
        vpn_connection_state.dart
        vpn_session_state.dart   # Recommended next addition.
      presentation/
        home_screen.dart
        widgets/
          connect_power_button.dart
          connection_status_card.dart
          license_expiry_chip.dart
          server_status_row.dart
```

Avoid creating abstract layers just for pattern purity. Add a new folder only when at least two related files need a home.

## UI improvement plan

### 1. Create small reusable UI widgets

`HomeScreen` currently owns header, expiry chip, expired banner, status copy, and server row. Split these when editing the UI:

- `connection_status_card.dart`: status title, subtitle, optional icon, connection health.
- `license_expiry_chip.dart`: expiry display.
- `expired_license_banner.dart`: renewal warning and call to action.
- `server_status_row.dart`: current server label, latency, auto/manual state.
- `vpn_home_header.dart`: app title and license/settings actions.

Keep widgets dumb. They should receive values and callbacks, not read repositories.

### 2. Improve visual hierarchy

Recommended home layout:

1. Top header with app name, active server, and license/settings action.
2. Status card with `Protected`, `Connecting`, `Exposed`, or `License required`.
3. Large power button in a `RepaintBoundary`.
4. Server card showing:
   - server display name,
   - mode: Auto or Selected,
   - latency if known,
   - protocol label: V2Ray/Xray.
5. License strip showing expiry and renewal action when needed.

### 3. Add responsive polish

- Use `LayoutBuilder` in `HomeScreen` if the vertical layout overflows on small phones.
- Move repeated hard-coded sizes into `core/design/nova_spacing.dart`.
- Add minimum touch targets for all controls.
- Use semantic labels on action widgets, especially the power button.
- Keep Sea Blue `#006994` as the brand anchor, with white/light surfaces.

### 4. Improve UX states

Add clear copy for these states:

- No license: "Activate a license to connect."
- Expired license: "Your license expired. Renew to reconnect."
- VPN permission denied: explain that system VPN permission is required.
- Native start failure: offer retry and support guidance.
- Server config missing: explain that the service is temporarily unavailable.

Do not expose raw Firebase or plugin exception text in production UI.

## Logic improvement plan

### 1. Add a richer session state

`VpnConnectionState` only represents the tunnel. The app also needs license/config status. Add a domain model such as:

```dart
enum LicenseStatus {
  unknown,
  missing,
  active,
  expired,
}

class VpnSessionState {
  const VpnSessionState({
    required this.tunnel,
    required this.license,
    this.expiresAt,
    this.lastError,
  });

  final VpnConnectionState tunnel;
  final LicenseStatus license;
  final DateTime? expiresAt;
  final String? lastError;
}
```

Then let `VpnSessionController` expose one `sessionState` getter so widgets do not repeatedly recompute `busy`, `expired`, `connected`, and license availability.

### 2. Make startup hydration explicit

Today initial config is read in `main.dart` and passed into `VpnSessionController`. That works, but future LLM sessions should keep hydration intentional:

- Keep secure storage read before `runApp`, or
- Add `VpnSessionController.initialize()` if startup logic grows.

Do not silently read secure storage inside widgets.

### 3. Strengthen native VPN mapping

`FlutterV2rayVpnRepository._mapState()` currently maps broad string fragments. When testing with real devices, update mappings for actual `flutter_v2ray` states. Include:

- connecting,
- connected,
- disconnecting,
- disconnected/idle,
- error/failure when the plugin exposes it.

If native callbacks include upload/download traffic, expose that through a separate model instead of overloading `VpnConnectionState`.

### 4. Tighten Firebase response handling

`FirebaseLicenseRepository` already accepts aliases. Improve it by:

- validating that `expiresAt` is in the future,
- mapping expired/missing config to `LicenseActivationFailure`,
- parsing Firestore Timestamp shapes consistently,
- avoiding raw exception text in release builds.

The callable should remain the only source of server config. Never hardcode server IPs in Flutter code.

### 5. Improve config freshness

Current model stores V2Ray config after activation. For production, choose one policy:

- Short-lived config: refetch config on each connect if expiry is close.
- Cached config: keep config until license expiry and support server-side revocation on next activation/check.
- Token model: store a short-lived token and request config just-in-time.

For a VPN app, short-lived config or token model is safer than long-lived cached config.

## Cursor coding standards for future agents

Follow these rules when asking an LLM to modify this repo:

- Read `.cursor/skills/novanet-vpn-app/SKILL.md` first for VPN, Firebase, storage, or controller work.
- Do not call Firebase, Firestore, Cloud Functions, `flutter_v2ray`, or platform APIs from `presentation/`.
- Route business logic through `VpnSessionController` or a feature controller.
- Keep repository implementations under `features/*/data/`.
- Keep app wiring in `lib/app/nova_providers.dart`.
- Keep reusable colors, theme, strings, and errors in `lib/core/`.
- Use constructor injection for anything that needs tests.
- Run `flutter analyze`, `flutter test`, and `dart format --output=none --set-exit-if-changed lib test` after code changes.

## Suggested implementation milestones

### Milestone 1: UI cleanup

- Split `HomeScreen` private widgets into files under `features/vpn/presentation/widgets/`.
- Add `core/design/nova_spacing.dart`.
- Add status card, server card, and better empty/license-required states.
- Keep `HomeScreen` mostly composition and callbacks.

### Milestone 2: Session state model

- Add `license_state.dart` or `vpn_session_state.dart`.
- Expose `VpnSessionController.sessionState`.
- Update UI to consume derived state from the controller instead of recomputing booleans.
- Add unit tests for missing, active, expired, connecting, connected, and error states.

### Milestone 3: Native VPN hardening

- Test `FlutterV2rayVpnRepository` on Android device.
- Update `_mapState()` with real plugin status strings.
- Add user-friendly mapping for permission denied and start failure.
- Document any Android manifest or iOS entitlement requirements.

### Milestone 4: Firebase hardening

- Update `FirebaseLicenseRepository` validation.
- Add tests with fake callable responses if practical.
- Keep `docs/FIREBASE.md` synchronized with accepted response shape.
- Ensure the Cloud Function reads config from `v2ray_configs`, not from client code.

### Milestone 5: Product readiness

- Add onboarding for first-run VPN permission.
- Add settings/about screen.
- Add diagnostics screen for device ID, license expiry, and last tunnel error.
- Add CI gates for format, analyze, and tests.

## LLM prompt template for later

Use this prompt to continue safely:

```text
Read docs/LLM_IMPROVEMENT_HANDOFF.md and .cursor/skills/novanet-vpn-app/SKILL.md first.

Task:
Implement Milestone <number/name> only.

Constraints:
- Do not call Firebase or flutter_v2ray from widgets.
- Keep app wiring in lib/app/nova_providers.dart.
- Keep feature code under lib/features/<feature>/.
- Preserve the current repository interfaces unless the task explicitly migrates all call sites.
- Update or add focused tests.
- Run flutter analyze and flutter test.

Return:
- Summary of changed files.
- Behavior changed.
- Verification performed.
- Any remaining risks.
```

## Priority recommendation

Start with Milestone 1 and Milestone 2 before adding more product screens. The app already has the correct repository wiring, but `HomeScreen` and the session booleans will become harder to maintain as soon as server selection, traffic stats, onboarding, and renewal flows are added.
