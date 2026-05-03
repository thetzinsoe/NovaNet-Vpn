import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_errors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../license/presentation/license_screen.dart';
import '../application/vpn_session_controller.dart';
import '../domain/vpn_connection_state.dart';
import 'widgets/connect_power_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<VpnSessionController>();
    final tunnel = session.tunnelState;
    final isNativeVpn = AppConfig.shouldUseNativeVpn;
    final busy =
        tunnel == VpnConnectionState.connecting ||
        tunnel == VpnConnectionState.disconnecting;
    final connected = tunnel == VpnConnectionState.connected;
    final expired = session.isLicenseExpired && !session.hasActiveLicense;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Header(
                onLicenseTap: () {
                  Navigator.of(context).pushNamed(LicenseScreen.routeName);
                },
                onDebugTap: () async {
                  final report = session.buildDebugReport();
                  await showDialog<void>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Debug report'),
                        content: SizedBox(
                          width: 520,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              report,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: report),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Debug report copied'),
                                ),
                              );
                            },
                            child: const Text('Copy'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              if (session.hasActiveLicense && session.licenseExpiresAt != null)
                _ExpiryChip(expiresAt: session.licenseExpiresAt!),
              if (!isNativeVpn) ...[
                const SizedBox(height: 12),
                const _DemoModeBanner(),
              ],
              if (expired) ...[
                const SizedBox(height: 12),
                const _ExpiredBanner(),
              ],
              const SizedBox(height: 48),
              Text(
                _statusTitle(tunnel, session.hasActiveLicense, isNativeVpn),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusSubtitle(tunnel, isNativeVpn),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 44),
              Center(
                child: RepaintBoundary(
                  child: ConnectPowerButton(
                    busy: busy,
                    isOn: connected,
                    enabled: session.hasActiveLicense && !expired,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        if (connected) {
                          await session.disconnect();
                        } else {
                          await session.connect();
                        }
                      } on LicenseException catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.message)),
                        );
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushNamed(LicenseScreen.routeName);
                        }
                      } on StateError catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.message)),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('${AppErrors.network} ($e)')),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _ServerRow(isNativeVpn: isNativeVpn),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusTitle(
    VpnConnectionState s,
    bool licensed,
    bool isNativeVpn,
  ) {
    return switch (s) {
      VpnConnectionState.idle =>
        licensed ? AppStrings.idle : AppStrings.noLicenseHint,
      VpnConnectionState.connecting => AppStrings.connecting,
      VpnConnectionState.connected =>
        isNativeVpn ? AppStrings.connected : AppStrings.demoConnected,
      VpnConnectionState.disconnecting => 'Disconnecting…',
      VpnConnectionState.error => 'Connection issue',
    };
  }

  static String _statusSubtitle(VpnConnectionState s, bool isNativeVpn) {
    return switch (s) {
      VpnConnectionState.idle => 'Tap the power button to secure your traffic.',
      VpnConnectionState.connecting => 'Negotiating tunnel…',
      VpnConnectionState.connected =>
        isNativeVpn
            ? 'Traffic is routed through NovaNet.'
            : 'UI flow is connected, but Android VPN service is not active.',
      VpnConnectionState.disconnecting => 'Closing tunnel…',
      VpnConnectionState.error => 'Try again or pick another server.',
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLicenseTap, required this.onDebugTap});

  final VoidCallback onLicenseTap;
  final VoidCallback onDebugTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            AppStrings.appName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Debug report',
          onPressed: onDebugTap,
          icon: const Icon(Icons.bug_report_outlined),
        ),
        IconButton(
          tooltip: AppStrings.licenseTitle,
          onPressed: onLicenseTap,
          icon: const Icon(Icons.vpn_key_outlined),
        ),
      ],
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  const _ExpiryChip({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final d = expiresAt.toLocal();
    final label =
        'License valid until ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: const Icon(Icons.schedule, size: 18, color: AppColors.accent),
        label: Text(label),
        side: const BorderSide(color: AppColors.outlineMuted),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}

class _ExpiredBanner extends StatelessWidget {
  const _ExpiredBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.expiredTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.expiredBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.demoModeTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.demoModeBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({required this.isNativeVpn});

  final bool isNativeVpn;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.public,
          size: 18,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 8),
        Text(
          isNativeVpn ? 'Server: Auto (nearest)' : 'Mode: Demo tunnel',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
