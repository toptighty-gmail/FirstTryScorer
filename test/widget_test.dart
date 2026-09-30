import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_try_scorer/config/supabase_config.dart';
import 'package:first_try_scorer/main.dart';
import 'package:first_try_scorer/models/game.dart';
import 'package:first_try_scorer/models/pick.dart';
import 'package:first_try_scorer/screens/draw_confirmation_screen.dart';
import 'package:first_try_scorer/screens/home_screen.dart';
import 'package:first_try_scorer/widgets/responsive_app_frame.dart';
import 'package:first_try_scorer/widgets/ticket_payment_agreement_dialog.dart';

void main() {
  test('Supabase config reads the environment values supplied at runtime', () {
    expect(SupabaseConfig.url, 'https://apckwnzahhgaecipuxen.supabase.co');
    expect(
      SupabaseConfig.anonKey,
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwY2t3bnphaGhnYWVjaXB1eGVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3ODQ2MTgsImV4cCI6MjEwNjM2MDYxOH0.L4IPDS2lWCzBD0o7aVEK6JGUWcWk4ndvcM3mgW-N-IM',
    );
  });

  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const FirstTryScorerApp());
    expect(find.byType(FirstTryScorerApp), findsOneWidget);
    expect(find.text('Version 1.0.14  |  Build 15'), findsOneWidget);
  });

  test('Responsive app widths suit common device classes', () {
    expect(ResponsiveAppFrame.maxWidthFor(390), 390);
    expect(ResponsiveAppFrame.maxWidthFor(768), 800);
    expect(ResponsiveAppFrame.maxWidthFor(1366), 1120);
    expect(ResponsiveAppFrame.maxWidthFor(2560), 1280);
  });

  testWidgets('History is hidden from signed-out users', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsNothing);
  });

  testWidgets('Allocation summary shows the slot and payment details', (
    WidgetTester tester,
  ) async {
    final game = Game(
      id: 'game-id',
      matchDate: DateTime(2026, 10, 1),
      homeTeamId: 'home-id',
      awayTeamId: 'away-id',
      homeTeamName: 'Home Team',
      awayTeamName: 'Away Team',
      joinCode: 'ABC123',
      status: 'open',
      ticketPrice: 5.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DrawConfirmationScreen(
          game: game,
          playerName: 'Alex Player',
          team: PickTeam.home,
          number: 7,
        ),
      ),
    );

    expect(find.text('Allocation confirmed'), findsOneWidget);
    expect(find.text('Home Team #7'), findsOneWidget);
    expect(
      find.text('Mr J Dobson\nSort Code: 77-09-23\nAccount No: 27186560'),
      findsOneWidget,
    );
    expect(find.text('Continue to game board'), findsOneWidget);
    expect(find.text('Choose another ticket allocation'), findsOneWidget);
    expect(find.text('Exit to home'), findsOneWidget);
  });

  testWidgets('Payment agreement requires acceptance before drawing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TicketPaymentAgreementDialog(ticketPrice: 5.5)),
    );

    expect(
      find.text('I agree to pay £5.50 for my ticket allocation.'),
      findsOneWidget,
    );
    var agreeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Agree and draw'),
    );
    expect(agreeButton.onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    agreeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Agree and draw'),
    );
    expect(agreeButton.onPressed, isNotNull);
  });

  test('Game maps a database ticket price', () {
    final game = Game.fromMap({
      'id': 'game-id',
      'match_date': '2026-10-01',
      'home_team_id': 'home-id',
      'away_team_id': 'away-id',
      'home': {'name': 'Home Team'},
      'away': {'name': 'Away Team'},
      'join_code': 'ABC123',
      'status': 'open',
      'ticket_price': 7.5,
    });

    expect(game.ticketPrice, 7.5);
  });
}
