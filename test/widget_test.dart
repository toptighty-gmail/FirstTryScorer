import 'package:flutter_test/flutter_test.dart';

import 'package:first_try_scorer/config/supabase_config.dart';
import 'package:first_try_scorer/main.dart';

void main() {
  test('Supabase config reads the environment values supplied at runtime', () {
    expect(SupabaseConfig.url, 'https://apckwnzahhgaecipuxen.supabase.co');
    expect(SupabaseConfig.anonKey,
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwY2t3bnphaGhnYWVjaXB1eGVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3ODQ2MTgsImV4cCI6MjEwNjM2MDYxOH0.L4IPDS2lWCzBD0o7aVEK6JGUWcWk4ndvcM3mgW-N-IM');
  });

  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const FirstTryScorerApp());
    expect(find.byType(FirstTryScorerApp), findsOneWidget);
    expect(find.text('Version 1.0.2  |  Build 3'), findsOneWidget);
  });
}
