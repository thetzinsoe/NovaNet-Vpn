import 'package:flutter_test/flutter_test.dart';
import 'package:novanet_vpn/app/nova_providers.dart';
import 'package:novanet_vpn/features/license/data/license_repository.dart';
import 'package:novanet_vpn/features/vpn/data/vpn_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_license_config_storage.dart';

void main() {
  testWidgets('NovaNet home loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      novaProvidersApp(
        prefs: prefs,
        configStorage: MemoryLicenseConfigStorage(),
        vpnRepository: StubVpnRepository(),
        licenseRepository: StubLicenseRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NovaNet VPN'), findsOneWidget);
  });
}
