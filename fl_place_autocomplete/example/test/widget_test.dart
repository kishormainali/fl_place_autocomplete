import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:fl_place_autocomplete_example/main.dart';
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart'
    show FlPlaceAutocompletePlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform extends FlPlaceAutocompletePlatform
    with MockPlatformInterfaceMixin {
  final findInputs = <String>[];
  final fetchIds = <String>[];
  PredictionOptions? lastOptions;
  Set<PlaceField>? lastFields;

  @override
  Future<List<PlacePrediction>> findPredictions(
    String input, {
    String? sessionId,
    required PredictionOptions options,
  }) async {
    findInputs.add(input);
    lastOptions = options;
    return [
      PlacePrediction(
        placeId: 'louvre',
        fullText: 'Louvre Museum, Paris, France',
        primaryText: 'Louvre Museum',
        secondaryText: 'Paris, France',
        matchedRanges: const [MatchedRange(0, 6)],
        types: const ['museum'],
        distanceMeters: 1200,
      ),
    ];
  }

  @override
  Future<Place> fetchPlace(
    String placeId, {
    String? sessionId,
    required Set<PlaceField> fields,
    String? languageCode,
    String? regionCode,
  }) async {
    fetchIds.add(placeId);
    lastFields = fields;
    return const Place(
      id: 'louvre',
      displayName: 'Louvre Museum',
      formattedAddress: 'Rue de Rivoli, 75001 Paris, France',
      location: LatLng(48.8606, 2.3376),
      types: ['museum', 'tourist_attraction'],
    );
  }

  @override
  Future<void> disposeSession(String sessionId) async {}
}

Finder _textFieldIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

void main() {
  late FakePlatform fake;

  setUp(() {
    fake = FakePlatform();
    FlPlaceAutocompletePlatform.instance = fake;
  });

  testWidgets('renders the three tabs', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Headless'), findsOneWidget);
    expect(find.text('Default field'), findsOneWidget);
    expect(find.text('Custom field'), findsOneWidget);
    expect(find.byKey(const ValueKey('headless-input')), findsOneWidget);

    await tester.tap(find.text('Default field'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('default-field')), findsOneWidget);

    await tester.tap(find.text('Custom field'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-field')), findsOneWidget);
    expect(find.text('Search US places'), findsOneWidget);

    expect(tester.takeException(), isNull);
    expect(fake.findInputs, isEmpty);
  });

  testWidgets('default field only queries after user input', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Default field'));
    await tester.pumpAndSettle();

    final field = _textFieldIn(const ValueKey('default-field'));
    expect(find.text('Eiffel Tower, Paris'), findsOneWidget);

    // Focusing and waiting past the debounce must not query the initial value.
    await tester.tap(field);
    await tester.pump(const Duration(seconds: 1));
    expect(fake.findInputs, isEmpty);

    await tester.enterText(field, 'Louvre');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(fake.findInputs, ['Louvre']);

    await tester.tap(find.text('Paris, France'));
    await tester.pumpAndSettle();
    expect(fake.fetchIds, ['louvre']);
    expect(find.byKey(const ValueKey('place-details')), findsOneWidget);
    expect(find.text('48.8606, 2.3376'), findsOneWidget);
    expect(find.text('museum, tourist_attraction'), findsOneWidget);
  });

  testWidgets('custom field requests all fields restricted to the US', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Custom field'));
    await tester.pumpAndSettle();

    await tester.enterText(_textFieldIn(const ValueKey('custom-field')), 'Lou');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(fake.findInputs, ['Lou']);
    expect(fake.lastOptions!.includedRegionCodes, ['us']);
    expect(find.text('1.2 km'), findsOneWidget);

    await tester.tap(find.text('Paris, France'));
    await tester.pumpAndSettle();
    expect(fake.lastFields, PlaceField.values.toSet());
    expect(find.byKey(const ValueKey('place-details')), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('place-details')), findsNothing);
  });
}
