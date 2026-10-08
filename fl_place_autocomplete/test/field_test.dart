import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_platform.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  late FakePlatform platform;
  late FlPlaceAutocomplete api;
  setUp(() {
    platform = FakePlatform();
    api = FlPlaceAutocomplete(platform: platform);
  });

  testWidgets('initialValue: no API call on build, focus, or pump', (tester) async {
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, initialValue: 'Eiffel Tower')));
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Eiffel Tower'), findsOneWidget);
    expect(platform.totalCalls, 0);
    expect(find.text('Powered by Google'), findsNothing); // overlay closed
  });

  testWidgets('initialPlace populates controller without onPlaceSelected', (tester) async {
    final c = PlaceAutocompleteController();
    var fired = 0;
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api, controller: c, initialPlace: const Place(id: 'p', formattedAddress: 'Addr'), onPlaceSelected: (_) => fired++)));
    expect(c.selectedPlace!.id, 'p');
    expect(find.text('Addr'), findsOneWidget);
    expect(fired, 0);
    expect(platform.totalCalls, 0);
  });

  testWidgets('typing shows predictions; tapping one fetches details and calls onPlaceSelected', (tester) async {
    Place? picked;
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, onPlaceSelected: (p) => picked = p)));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Text pizza-1'), findsOneWidget);
    expect(find.text('Powered by Google'), findsOneWidget);
    await tester.tap(find.text('Text pizza-1'));
    await tester.pump();
    await tester.pump();
    expect(picked!.location, const LatLng(1, 2));
    expect(platform.fetchCalls.single.sessionId, platform.findCalls.single.sessionId);
    expect(find.text('Text pizza-1'), findsOneWidget); // now in the text field only
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('custom predictionBuilder, emptyBuilder and footer are used', (tester) async {
    platform.onFind = (i) async => i == 'none' ? [] : [prediction('a')];
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api,
      predictionBuilder: (c, p, h, onTap) => TextButton(onPressed: onTap, child: Text('ROW ${p.placeId}')),
      emptyBuilder: (c, q) => Text('EMPTY $q'),
      footerBuilder: (c) => const Text('MY FOOTER'),
    )));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('ROW a'), findsOneWidget);
    expect(find.text('MY FOOTER'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'none');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('EMPTY none'), findsOneWidget);
  });

  testWidgets('errorBuilder shows and retry re-queries', (tester) async {
    var fail = true;
    platform.onFind = (_) => fail ? Future.error(const PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.networkError)) : Future.value([prediction('ok')]);
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api, errorBuilder: (c, e, retry) => TextButton(onPressed: retry, child: Text('ERR ${e.code.name}')))));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('ERR networkError'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('ERR networkError'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Text ok'), findsOneWidget);
  });

  testWidgets('keyboard: arrow down + enter selects; escape closes', (tester) async {
    Place? picked;
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, onPlaceSelected: (p) => picked = p)));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(picked, isNotNull);

    await tester.enterText(find.byType(TextField), 'tacos');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('default tile tolerates empty secondary text and out-of-range matches', (tester) async {
    platform.onFind = (_) async => [
          const PlacePrediction(placeId: 'x', fullText: 'Ab', primaryText: 'Ab', secondaryText: '', matchedRanges: [MatchedRange(-4, 99)], types: []),
          const PlacePrediction(placeId: 'y', fullText: '', primaryText: '', secondaryText: '', matchedRanges: [MatchedRange(0, 3)], types: []),
        ];
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api)));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('disposing the field mid-request does not throw', (tester) async {
    platform.onFind = (_) => Future.delayed(const Duration(seconds: 1), () => [prediction('a')]);
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api)));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fieldBuilder receives controller and focus node', (tester) async {
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api,
      fieldBuilder: (c, controller, focusNode, onSubmit) => TextField(key: const Key('mine'), controller: controller.textController, focusNode: focusNode),
    )));
    await tester.enterText(find.byKey(const Key('mine')), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(platform.findCalls, hasLength(1));
  });

  // ---- additional coverage (focus/blur rules, keyboard pass-through, M1) ----

  testWidgets('focus alone never opens the overlay or calls the API', (tester) async {
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, autofocus: true)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(seconds: 1));
    expect(platform.totalCalls, 0);
    expect(find.text('Powered by Google'), findsNothing);
  });

  testWidgets('arrow keys are not consumed while the overlay is closed', (tester) async {
    final bubbled = <LogicalKeyboardKey>[];
    await tester.pumpWidget(host(Focus(
      canRequestFocus: false,
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent) bubbled.add(e.logicalKey);
        return KeyEventResult.ignored;
      },
      child: PlaceAutocompleteField(api: api),
    )));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(bubbled, [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.escape, LogicalKeyboardKey.enter]);

    // ...whereas with the overlay open the field consumes them.
    bubbled.clear();
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(bubbled, isEmpty);
  });

  testWidgets('blur closes the overlay and disposes the session', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(host(Column(children: [
      PlaceAutocompleteField(api: api, focusNode: focus),
      const TextField(key: Key('other')),
    ])));
    await tester.enterText(find.byType(TextField).first, 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    focus.unfocus();
    await tester.pump();
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
    expect(platform.disposed, [platform.findCalls.single.sessionId]);
  });

  testWidgets('tapping a row keeps focus in the field (TapRegion group)', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final c = PlaceAutocompleteController();
    addTearDown(c.dispose);
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, controller: c, focusNode: focus, fetchDetailsOnSelect: false)));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.text('Text pizza-1').last), kind: PointerDeviceKind.mouse);
    await gesture.up();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(platform.disposed, isEmpty);
  });

  testWidgets('M1: fetchDetailsOnSelect=false, takeSession() in onPredictionSelected returns a live session', (tester) async {
    final c = PlaceAutocompleteController();
    addTearDown(c.dispose);
    PlaceSession? taken;
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api,
      controller: c,
      fetchDetailsOnSelect: false,
      onPredictionSelected: (_) => taken = c.takeSession(),
    )));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.tap(find.text('Text pizza-1').last);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(taken, isNotNull);
    expect(taken!.isEnded, isFalse);
    expect(taken!.id, platform.findCalls.single.sessionId);
    expect(platform.fetchCalls, isEmpty);
    expect(platform.disposed, isEmpty);
  });

  testWidgets('swapping the controller re-attaches config and keeps working', (tester) async {
    final a = PlaceAutocompleteController();
    final b = PlaceAutocompleteController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, controller: a)));
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, controller: b)));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(b.status, PlaceAutocompleteStatus.results);
    expect(find.text('Text pizza-1'), findsOneWidget);
  });
}
