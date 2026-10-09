import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  late FakePlatform platform;
  late FlPlaceAutocomplete api;
  setUp(() {
    platform = FakePlatform();
    api = FlPlaceAutocomplete(platform: platform);
  });

  testWidgets('initialValue: no API call on build, focus, or pump', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(PlaceAutocompleteField(api: api, initialValue: 'Eiffel Tower')),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Eiffel Tower'), findsOneWidget);
    expect(platform.totalCalls, 0);
    expect(find.text('Powered by Google'), findsNothing); // overlay closed
  });

  testWidgets('initialPlace populates controller without onPlaceSelected', (
    tester,
  ) async {
    final c = PlaceAutocompleteController();
    var fired = 0;
    await tester.pumpWidget(
      host(
        PlaceAutocompleteField(
          api: api,
          controller: c,
          initialPlace: const Place(id: 'p', formattedAddress: 'Addr'),
          onPlaceSelected: (_) => fired++,
        ),
      ),
    );
    expect(c.selectedPlace!.id, 'p');
    expect(find.text('Addr'), findsOneWidget);
    expect(fired, 0);
    expect(platform.totalCalls, 0);
  });

  testWidgets(
    'typing shows predictions; tapping one fetches details and calls onPlaceSelected',
    (tester) async {
      Place? picked;
      await tester.pumpWidget(
        host(
          PlaceAutocompleteField(api: api, onPlaceSelected: (p) => picked = p),
        ),
      );
      await tester.enterText(find.byType(TextField), 'pizza');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Text pizza-1'), findsOneWidget);
      expect(find.text('Powered by Google'), findsOneWidget);
      await tester.tap(find.text('Text pizza-1'));
      await tester.pump();
      await tester.pump();
      expect(picked!.location, const LatLng(1, 2));
      expect(
        platform.fetchCalls.single.sessionId,
        platform.findCalls.single.sessionId,
      );
      expect(
        find.text('Text pizza-1'),
        findsOneWidget,
      ); // now in the text field only
      expect(find.byType(ListTile), findsNothing);
    },
  );

  testWidgets('custom predictionBuilder, emptyBuilder and footer are used', (
    tester,
  ) async {
    platform.onFind = (i) async => i == 'none' ? [] : [prediction('a')];
    await tester.pumpWidget(
      host(
        PlaceAutocompleteField(
          api: api,
          predictionBuilder: (c, p, h, onTap) =>
              TextButton(onPressed: onTap, child: Text('ROW ${p.placeId}')),
          emptyBuilder: (c, q) => Text('EMPTY $q'),
          footerBuilder: (c) => const Text('MY FOOTER'),
        ),
      ),
    );
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
    platform.onFind = (_) => fail
        ? Future.error(
            const PlaceAutocompleteException(
              code: PlaceAutocompleteErrorCode.networkError,
            ),
          )
        : Future.value([prediction('ok')]);
    await tester.pumpWidget(
      host(
        PlaceAutocompleteField(
          api: api,
          errorBuilder: (c, e, retry) =>
              TextButton(onPressed: retry, child: Text('ERR ${e.code.name}')),
        ),
      ),
    );
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

  testWidgets('keyboard: arrow down + enter selects; escape closes', (
    tester,
  ) async {
    Place? picked;
    await tester.pumpWidget(
      host(
        PlaceAutocompleteField(api: api, onPlaceSelected: (p) => picked = p),
      ),
    );
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

  testWidgets(
    'default tile tolerates empty secondary text and out-of-range matches',
    (tester) async {
      platform.onFind = (_) async => [
        const PlacePrediction(
          placeId: 'x',
          fullText: 'Ab',
          primaryText: 'Ab',
          secondaryText: '',
          matchedRanges: [MatchedRange(-4, 99)],
          types: [],
        ),
        const PlacePrediction(
          placeId: 'y',
          fullText: '',
          primaryText: '',
          secondaryText: '',
          matchedRanges: [MatchedRange(0, 3)],
          types: [],
        ),
      ];
      await tester.pumpWidget(host(PlaceAutocompleteField(api: api)));
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ListTile), findsNWidgets(2));
    },
  );

  testWidgets('disposing the field mid-request does not throw', (tester) async {
    platform.onFind = (_) =>
        Future.delayed(const Duration(seconds: 1), () => [prediction('a')]);
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api)));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fieldBuilder receives controller and focus node', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PlaceAutocompleteField(
          api: api,
          fieldBuilder: (c, controller, focusNode, onSubmit) => TextField(
            key: const Key('mine'),
            controller: controller.textController,
            focusNode: focusNode,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('mine')), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(platform.findCalls, hasLength(1));
  });

  // ---- additional coverage (focus/blur rules, keyboard pass-through, M1) ----

  testWidgets('focus alone never opens the overlay or calls the API', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(PlaceAutocompleteField(api: api, autofocus: true)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(seconds: 1));
    expect(platform.totalCalls, 0);
    expect(find.text('Powered by Google'), findsNothing);
  });

  testWidgets('arrow keys are not consumed while the overlay is closed', (
    tester,
  ) async {
    final bubbled = <LogicalKeyboardKey>[];
    await tester.pumpWidget(
      host(
        Focus(
          canRequestFocus: false,
          onKeyEvent: (_, e) {
            if (e is KeyDownEvent) bubbled.add(e.logicalKey);
            return KeyEventResult.ignored;
          },
          child: PlaceAutocompleteField(api: api),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(bubbled, [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.enter,
    ]);

    // ...whereas with the overlay open the field consumes them.
    bubbled.clear();
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(bubbled, isEmpty);
  });

  testWidgets('blur closes the overlay and disposes the session', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      host(
        Column(
          children: [
            PlaceAutocompleteField(api: api, focusNode: focus),
            const TextField(key: Key('other')),
          ],
        ),
      ),
    );
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

  testWidgets('tapping a row keeps focus in the field (TapRegion group)', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final c = PlaceAutocompleteController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        PlaceAutocompleteField(
          api: api,
          controller: c,
          focusNode: focus,
          fetchDetailsOnSelect: false,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Text pizza-1').last),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(platform.disposed, isEmpty);
  });

  testWidgets(
    'M1: fetchDetailsOnSelect=false, takeSession() in onPredictionSelected returns a live session',
    (tester) async {
      final c = PlaceAutocompleteController();
      addTearDown(c.dispose);
      PlaceSession? taken;
      await tester.pumpWidget(
        host(
          PlaceAutocompleteField(
            api: api,
            controller: c,
            fetchDetailsOnSelect: false,
            onPredictionSelected: (_) => taken = c.takeSession(),
          ),
        ),
      );
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
    },
  );

  testWidgets('swapping the controller re-attaches config and keeps working', (
    tester,
  ) async {
    final a = PlaceAutocompleteController();
    final b = PlaceAutocompleteController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(
      host(PlaceAutocompleteField(api: api, controller: a)),
    );
    await tester.pumpWidget(
      host(PlaceAutocompleteField(api: api, controller: b)),
    );
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(b.status, PlaceAutocompleteStatus.results);
    expect(find.text('Text pizza-1'), findsOneWidget);
  });

  group('final review fixes', () {
    testWidgets(
      'custom fieldBuilder: a mouse tap on a row selects instead of blurring',
      (tester) async {
        Place? picked;
        final c = PlaceAutocompleteController();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          host(
            PlaceAutocompleteField(
              api: api,
              controller: c,
              onPlaceSelected: (p) => picked = p,
              fieldBuilder: (context, controller, focusNode, onSubmit) =>
                  TextField(
                    controller: controller.textController,
                    focusNode: focusNode,
                  ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'pizza');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Text pizza-1').last),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(); // a frame between pointer down and up
        await gesture.up();
        await tester.pump();
        await tester.pump();
        expect(picked, isNotNull);
        expect(platform.disposed, isEmpty);
        expect(
          platform.fetchCalls.single.sessionId,
          platform.findCalls.single.sessionId,
        );
        expect(c.session, isNull); // ended by the successful fetch
      },
    );

    testWidgets(
      'disposing a field with an external controller mid-debounce sends no request',
      (tester) async {
        final c = PlaceAutocompleteController();
        addTearDown(c.dispose);
        var errors = 0;
        await tester.pumpWidget(
          host(
            PlaceAutocompleteField(
              api: api,
              controller: c,
              onError: (_) => errors++,
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'pizza');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        expect(platform.findCalls, isEmpty);
        expect(errors, 0);
      },
    );

    testWidgets(
      'disposing a field with an external controller cancels its session',
      (tester) async {
        final c = PlaceAutocompleteController();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          host(PlaceAutocompleteField(api: api, controller: c)),
        );
        await tester.enterText(find.byType(TextField), 'pizza');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        final sid = c.session!.id;
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(platform.disposed, [sid]);
        expect(c.session, isNull);
      },
    );

    testWidgets('swapping out an external controller detaches it', (
      tester,
    ) async {
      final a = PlaceAutocompleteController();
      final b = PlaceAutocompleteController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(
        host(PlaceAutocompleteField(api: api, controller: a)),
      );
      await tester.enterText(find.byType(TextField), 'pizza');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      final sid = a.session!.id;
      await tester.pumpWidget(
        host(PlaceAutocompleteField(api: api, controller: b)),
      );
      await tester.pump();
      expect(platform.disposed, [sid]);
      a.textController.text = 'tacos'; // detached: no request
      await tester.pump(const Duration(seconds: 1));
      expect(platform.findCalls, hasLength(1));
    });

    testWidgets(
      'swapping a focused focusNode for an unfocused one runs the blur path',
      (tester) async {
        final f1 = FocusNode();
        final f2 = FocusNode();
        addTearDown(f1.dispose);
        addTearDown(f2.dispose);
        await tester.pumpWidget(
          host(PlaceAutocompleteField(api: api, focusNode: f1)),
        );
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'pizza');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.byType(ListTile), findsOneWidget);
        expect(f1.hasFocus, isTrue);
        await tester.pumpWidget(
          host(PlaceAutocompleteField(api: api, focusNode: f2)),
        );
        await tester.pump();
        expect(f2.hasFocus, isFalse);
        expect(find.byType(ListTile), findsNothing);
        expect(platform.disposed, [platform.findCalls.single.sessionId]);
      },
    );
  });

  for (final mode in [
    PlaceSuggestionsMode.bottomSheet,
    PlaceSuggestionsMode.dialog,
  ]) {
    testWidgets('$mode: tap opens modal, selecting a row closes it', (
      tester,
    ) async {
      Place? picked;
      await tester.pumpWidget(
        host(
          PlaceAutocompleteField(
            api: api,
            suggestionsMode: mode,
            onPlaceSelected: (p) => picked = p,
          ),
        ),
      );
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2)); // inline + modal
      await tester.enterText(find.byType(TextField).last, 'pizza');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Powered by Google'), findsOneWidget);
      await tester.tap(find.text('Text pizza-1'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Powered by Google'), findsNothing);
      expect(picked!.location, const LatLng(1, 2));
    });
  }

  testWidgets('panelBuilder replaces the overlay chrome', (tester) async {
    await tester.pumpWidget(
      host(
        PlaceAutocompleteField(
          api: api,
          panelBuilder: (_, content) => Material(
            key: const Key('panel'),
            color: Colors.red,
            child: content,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const Key('panel')), findsOneWidget);
    expect(find.text('Text pizza-1'), findsOneWidget);
  });

  group('keyboard', () {
    const keyboard = 300.0;

    void openKeyboard(WidgetTester tester) {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(400, 800)
        ..viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);
    }

    Future<void> type(WidgetTester tester, Finder field) async {
      await tester.enterText(field, 'pizza');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    testWidgets('overlay flips above a field that sits on the keyboard', (
      tester,
    ) async {
      openKeyboard(tester);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              const Spacer(),
              PlaceAutocompleteField(
                api: api,
                openDirection: PlaceOverlayDirection.down,
              ),
            ],
          ),
        ),
      );
      await type(tester, find.byType(TextField));
      expect(find.text('Text pizza-1'), findsOneWidget);
      final field = tester.getRect(find.byType(TextField));
      final footer = tester.getRect(find.text('Powered by Google'));
      expect(footer.bottom, lessThanOrEqualTo(field.top));
      expect(tester.takeException(), isNull);
    });

    for (final mode in [
      PlaceSuggestionsMode.bottomSheet,
      PlaceSuggestionsMode.dialog,
    ]) {
      testWidgets('$mode stays above the keyboard', (tester) async {
        openKeyboard(tester);
        await tester.pumpWidget(
          host(PlaceAutocompleteField(api: api, suggestionsMode: mode)),
        );
        await tester.tap(find.byType(TextField), warnIfMissed: false);
        await tester.pumpAndSettle();
        await type(tester, find.byType(TextField).last);
        final footer = tester.getRect(find.text('Powered by Google'));
        final search = tester.getRect(find.byType(TextField).last);
        expect(footer.bottom, lessThanOrEqualTo(800 - keyboard));
        expect(search.bottom, lessThanOrEqualTo(800 - keyboard));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sheet and dialog options apply', (tester) async {
      openKeyboard(tester);
      await tester.pumpWidget(
        host(
          PlaceAutocompleteField(
            api: api,
            suggestionsMode: PlaceSuggestionsMode.dialog,
            dialogOptions: const PlaceDialogOptions(
              backgroundColor: Color(0xFF123456),
              maxWidth: 300,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFF123456));
      final panel = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Material),
      );
      expect(tester.getSize(panel.first).width, lessThanOrEqualTo(300));
    });

    for (final mode in [
      PlaceSuggestionsMode.bottomSheet,
      PlaceSuggestionsMode.dialog,
    ]) {
      testWidgets('$mode: modal search decoration and builder override', (
        tester,
      ) async {
        final sheet = mode == PlaceSuggestionsMode.bottomSheet;
        await tester.pumpWidget(
          host(
            PlaceAutocompleteField(
              api: api,
              suggestionsMode: mode,
              decoration: const InputDecoration(hintText: 'inline'),
              bottomSheetOptions: const PlaceBottomSheetOptions(
                searchDecoration: InputDecoration(hintText: 'modal'),
                autofocusSearch: false,
              ),
              dialogOptions: PlaceDialogOptions(
                searchFieldBuilder: (context, c, node, submit) => TextField(
                  key: const Key('custom-search'),
                  controller: c.textController,
                  focusNode: node,
                  onSubmitted: (_) => submit(),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField), warnIfMissed: false);
        await tester.pumpAndSettle();
        if (sheet) {
          expect(find.text('modal'), findsOneWidget);
          expect(find.text('inline'), findsOneWidget); // inline field remains
          final modal = tester.widget<TextField>(find.byType(TextField).last);
          expect(modal.autofocus, isFalse);
        } else {
          expect(find.byKey(const Key('custom-search')), findsOneWidget);
          await tester.enterText(
            find.byKey(const Key('custom-search')),
            'pizza',
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          expect(find.text('Text pizza-1'), findsOneWidget);
        }
      });
    }
  });

  group('theme decoration', () {
    final themed = ThemeData(
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(),
      ),
    );

    Widget app(Widget field) => MaterialApp(
      theme: themed,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: field),
      ),
    );

    InputDecoration decorationOf(WidgetTester tester, {bool last = false}) {
      final finder = find.byType(InputDecorator);
      return tester
          .widget<InputDecorator>(last ? finder.last : finder.first)
          .decoration;
    }

    for (final mode in PlaceSuggestionsMode.values) {
      testWidgets('$mode: inherits the theme and merges a custom decoration', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            PlaceAutocompleteField(
              api: api,
              suggestionsMode: mode,
              decoration: const InputDecoration(hintText: 'mine'),
            ),
          ),
        );
        var d = decorationOf(tester);
        expect(d.filled, isTrue); // from the theme
        expect(d.border, isA<OutlineInputBorder>()); // from the theme
        expect(d.hintText, 'mine'); // from the widget
        if (mode != PlaceSuggestionsMode.overlay) {
          await tester.tap(find.byType(TextField), warnIfMissed: false);
          await tester.pumpAndSettle();
          d = decorationOf(tester, last: true);
          expect(d.filled, isTrue);
          expect(d.border, isA<OutlineInputBorder>());
          expect(d.hintText, 'mine');
        }
      });
    }

    testWidgets('default decoration is the theme alone; a field can override', (
      tester,
    ) async {
      await tester.pumpWidget(app(PlaceAutocompleteField(api: api)));
      expect(decorationOf(tester).border, isA<OutlineInputBorder>());
      await tester.pumpWidget(
        app(
          PlaceAutocompleteField(
            api: api,
            decoration: const InputDecoration(
              filled: false,
              border: UnderlineInputBorder(),
            ),
          ),
        ),
      );
      expect(decorationOf(tester).filled, isFalse);
      expect(decorationOf(tester).border, isA<UnderlineInputBorder>());
    });
  });
}
