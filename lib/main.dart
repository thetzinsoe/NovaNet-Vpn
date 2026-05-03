import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/nova_providers.dart';
import 'core/config/app_config.dart';
import 'core/storage/license_config_storage.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.shouldUseFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final storage = SecureLicenseConfigStorage(prefs);
  final initialConfig = await storage.read();

  runApp(
    novaProvidersApp(
      prefs: prefs,
      initialV2RayConfig: initialConfig,
      configStorage: storage,
    ),
  );
}
