// Live test against the real Places API. Opt-in, because it needs a valid key
// configured natively (see README) and network access:
//
//   flutter test integration_test/live_test.dart --dart-define=LIVE=true
//   (or `flutter drive` / `-d chrome` for web)
import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:fl_place_autocomplete_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const bool live = bool.fromEnvironment('LIVE');

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live: type "Eiffel", select the first prediction, get a location',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Default field'));
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.byKey(const ValueKey('default-field')),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.enterText(field, 'Eiffel');

      final rows = find.byType(DefaultPredictionTile);
      await pumpUntilFound(tester, rows);
      expect(rows, findsAtLeastNWidgets(1));

      await tester.tap(rows.first);
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('place-location')),
      );
      expect(find.byKey(const ValueKey('default-error')), findsNothing);
    },
    skip: !live,
  );
}
