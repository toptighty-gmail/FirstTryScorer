import 'package:flutter_test/flutter_test.dart';

import 'package:first_try_scorer/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const FirstTryScorerApp());
    expect(find.byType(FirstTryScorerApp), findsOneWidget);
  });
}
