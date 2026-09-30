import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  }
  runApp(const FirstTryScorerApp());
}

class FirstTryScorerApp extends StatelessWidget {
  const FirstTryScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'First Try Scorer',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B5E20), useMaterial3: true),
      home: SupabaseConfig.isConfigured ? const HomeScreen() : const _NotConfiguredScreen(),
    );
  }
}

class _NotConfiguredScreen extends StatelessWidget {
  const _NotConfiguredScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase is not configured.\n\n'
            'Run with:\n'
            'flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
