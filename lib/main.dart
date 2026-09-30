import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
  runApp(const FirstTryScorerApp());
}

class FirstTryScorerApp extends StatelessWidget {
  const FirstTryScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'First Try Scorer',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5E20),
        useMaterial3: true,
      ),
      builder: (context, child) => Column(
        children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          const _AppVersionFooter(),
        ],
      ),
      home: SupabaseConfig.isConfigured
          ? const HomeScreen()
          : const _NotConfiguredScreen(),
    );
  }
}

class _AppVersionFooter extends StatefulWidget {
  const _AppVersionFooter();

  @override
  State<_AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<_AppVersionFooter> {
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 30,
          width: double.infinity,
          child: FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              final label = snapshot.hasData
                  ? 'Version ${snapshot.data!.version}  |  Build ${snapshot.data!.buildNumber}'
                  : 'Version 1.0.11  |  Build 12';
              return Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              );
            },
          ),
        ),
      ),
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
