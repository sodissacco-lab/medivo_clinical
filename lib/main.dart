import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'config.dart';
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