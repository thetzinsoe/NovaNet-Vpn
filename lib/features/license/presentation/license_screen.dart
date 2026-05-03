import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_errors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../vpn/application/vpn_session_controller.dart';
import 'license_key_input_formatter.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  static const routeName = '/license';

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _diagnosing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<VpnSessionController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await session.activateLicense(_controller.text.trim());
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('License activated.')),
      );
      Navigator.of(context).pop();
    } on LicenseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${AppErrors.activationFailed} ($e)')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runDiagnostics() async {
    final session = context.read<VpnSessionController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _diagnosing = true);
    try {
      final report = await session.diagnoseActivationTransport();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Activation diagnostics'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: SelectableText(
                  report.toMultilineText(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } on LicenseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${AppErrors.network} ($e)')),
      );
    } finally {
      if (mounted) setState(() => _diagnosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<VpnSessionController>();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.licenseTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Enter the 12-character key issued after purchase. It is bound to this device ID for validation.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            inputFormatters: const [LicenseKeyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'License key',
              hintText: AppStrings.licenseHint,
            ),
            onSubmitted: (_) => _loading ? null : _submit(),
          ),
          const SizedBox(height: 12),
          Text('Device ID', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SelectableText(
            session.deviceId,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.activate),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: (_loading || _diagnosing) ? null : _runDiagnostics,
            icon: _diagnosing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check_outlined),
            label: const Text('Run activation diagnostics'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: session.hasActiveLicense
                ? () => session.clearLicenseCache()
                : null,
            child: const Text('Clear saved license (debug)'),
          ),
        ],
      ),
    );
  }
}
