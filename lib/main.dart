import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'config.dart';
import 'offline/offline_service.dart';
import 'services/account_controller.dart';
import 'services/calculator_catalog.dart';
import 'services/library_service.dart';
import 'services/notification_service.dart';
import 'theme/medivo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connecting to Supabase needs no internet at start-up, so the app
  // still opens offline. If the settings are wrong we log it and carry on;
  // the "Test connection" button on the Me tab reports the problem.
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase could not start: $e');
  }

  // Listens for sign-in and sign-out and loads the profile (Phase 2).
  AccountController.instance.start();

  // Opens the on-phone library, then updates it in the background (Phase 4).
  await OfflineService.instance.init();
  OfflineService.instance.syncIfDue();
  CalculatorCatalog.instance.refresh();
  try {
    await LibraryService.instance.start(); // Saved and Recent (Phase 12)
  } catch (e) {
    debugPrint('Saved and recent could not start: $e');
  }
  NotificationService.instance.refresh();

  runApp(const MedivoApp());
}

class MedivoApp extends StatelessWidget {
  const MedivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medivo Clinical',
      debugShowCheckedModeBanner: false,
      theme: MedivoTheme.light(),
      darkTheme: MedivoTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}