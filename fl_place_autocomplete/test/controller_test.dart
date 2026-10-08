import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform.dart';

const debounce = Duration(milliseconds: 300);

({
  FakePlatform platform,
  PlaceAutocompleteController c,
  List<Place> places,
  List<PlaceAutocompleteException> errors,
})
setUpController() {
  final platform = FakePlatform();
  final places = <Place>[];
  final errors = <PlaceAutocompleteException>[];
  final c = PlaceAutocompleteController();
  c.attach(
    PlaceAutocompleteConfig(
      api: FlPlaceAutocomplete(platform: platform),
      options: PredictionOptions(),
      fields: defaultPlaceFields,
      onPlaceSelected: places.add,
      onError: errors.add,
    ),
  );
  return (platform: platform, c: c, places: places, errors: errors);
}

void main() {
  test('initial text, setText and setPlace never call the platform', () {
    fakeAsync((async) {
      final platform = FakePlatform();
      final c = PlaceAutocompleteController(text: 'Initial');
      c.attach(
        PlaceAutocompleteConfig(
          api: FlPlaceAutocomplete(platform: platform),
          options: PredictionOptions(),
          fields: defaultPlaceFields,
        ),
      );
      c.setText('Other');
      c.setPlace(const Place(id: 'x', formattedAddress: 'Addr'));
      async.elapse(const Duration(seconds: 2));
      expect(platform.totalCalls, 0);
      expect(c.textController.text, 'Addr');
      expect(c.selectedPlace!.id, 'x');
      expect(c.overlayOpen, isFalse);
    });
  });

  test('caret-only changes do not trigger a request', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      final before = t.platform.findCalls.length;
      t.c.textController.selection = const TextSelection.collapsed(offset: 2);
      async.elapse(const Duration(seconds: 1));
      expect(t.platform.findCalls.length, before);
    });
  });

  test('debounces typing and reuses one session', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pi';
      async.elapse(const Duration(milliseconds: 100));
      t.c.textController.text = 'piz';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.platform.findCalls.map((e) => e.input), ['piz']);
      t.c.textController.text = 'pizz';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.platform.findCalls.map((e) => e.sessionId).toSet().length, 1);
      expect(t.c.status, PlaceAutocompleteStatus.results);
      expect(t.c.overlayOpen, isTrue);
    });
  });

  test('below minChars no request is made', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'p';
      async.elapse(debounce * 2);
      expect(t.platform.totalCalls, 0);
      expect(t.c.status, PlaceAutocompleteStatus.idle);
    });
  });

  test('stale response from an older query is dropped', () {
    fakeAsync((async) {
      final t = setUpController();
      final first = Completer<List<PlacePrediction>>();
      t.platform.onFind = (input) =>
          input == 'pi' ? first.future : Future.value([prediction('new')]);
      t.c.textController.text = 'pi';
      async.elapse(debounce);
      t.c.textController.text = 'piz';
      async.elapse(debounce);
      async.flushMicrotasks();
      first.complete([prediction('old')]);
      async.flushMicrotasks();
      expect(t.c.predictions.single.placeId, 'new');
    });
  });

  test('select fetches details with the same session, ends it, fires callback once', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final sid = t.platform.findCalls.single.sessionId;
      t.c.select(t.c.predictions.single);
      async.flushMicrotasks();
      expect(t.platform.fetchCalls.single.sessionId, sid);
      expect(t.platform.fetchCalls.single.fields, defaultPlaceFields);
      expect(t.places.single.location, const LatLng(1, 2));
      expect(t.c.selectedPlace, isNotNull);
      expect(t.c.session, isNull);
      expect(t.c.overlayOpen, isFalse);
      // next typing starts a fresh session
      t.c.textController.text = 'pizzas';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.platform.findCalls.last.sessionId, isNot(sid));
    });
  });

  test('selection does not trigger a new prediction request', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.select(t.c.predictions.single);
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(t.platform.findCalls.length, 1);
    });
  });

  test('stale prediction response after selection does not reopen overlay or change text', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final late = Completer<List<PlacePrediction>>();
      t.platform.onFind = (_) => late.future;
      t.c.textController.text = 'pizzas';
      async.elapse(debounce); // request in flight
      t.c.select(prediction('p-1', text: 'Chosen'));
      async.flushMicrotasks();
      late.complete([prediction('stale')]);
      async.flushMicrotasks();
      expect(t.c.overlayOpen, isFalse);
      expect(t.c.textController.text, 'Chosen');
      expect(t.c.predictions, isEmpty);
    });
  });

  test(
    'editing text while the details fetch is in flight discards the result',
    () {
      fakeAsync((async) {
        final t = setUpController();
        final fetch = Completer<Place>();
        t.platform.onFetch = (_) => fetch.future;
        t.c.select(prediction('p', text: 'Chosen'));
        t.c.textController.text = 'Chosen but edited';
        fetch.complete(const Place(id: 'p'));
        async.flushMicrotasks();
        expect(t.c.selectedPlace, isNull);
        expect(t.places, isEmpty);
      });
    },
  );

  test('fetch failure keeps the session active, reports the error, and retry succeeds', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final session = t.c.session!;
      t.platform.onFetch = (_) => Future.error(
        const PlaceAutocompleteException(
          code: PlaceAutocompleteErrorCode.networkError,
        ),
      );
      t.c.select(t.c.predictions.single);
      async.flushMicrotasks();
      expect(t.errors.single.code, PlaceAutocompleteErrorCode.networkError);
      expect(t.c.status, PlaceAutocompleteStatus.error);
      expect(session.isEnded, isFalse);
      t.platform.onFetch = null;
      t.c.retry();
      async.flushMicrotasks();
      expect(t.places.single.id, 'pizza-1');
      expect(session.isEnded, isTrue);
    });
  });

  test('prediction failure surfaces error status and onError', () {
    fakeAsync((async) {
      final t = setUpController();
      t.platform.onFind = (_) => Future.error(
        const PlaceAutocompleteException(
          code: PlaceAutocompleteErrorCode.quotaExceeded,
        ),
      );
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.c.status, PlaceAutocompleteStatus.error);
      expect(t.errors.single.code, PlaceAutocompleteErrorCode.quotaExceeded);
    });
  });

  test('blur without selection disposes the session; blur during selection does not', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final sid = t.c.session!.id;
      t.c.onFocusLost();
      async.flushMicrotasks();
      expect(t.platform.disposed, [sid]);
      expect(t.c.overlayOpen, isFalse);

      final fetch = Completer<Place>();
      t.platform.onFetch = (_) => fetch.future;
      t.c.textController.text = 'tacos';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.select(t.c.predictions.single);
      t.c.onFocusLost();
      fetch.complete(const Place(id: 'tacos-1'));
      async.flushMicrotasks();
      expect(t.platform.disposed.length, 1);
      expect(t.places.single.id, 'tacos-1');
    });
  });

  test('clear resets text, selection and disposes the session', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.clear();
      async.flushMicrotasks();
      expect(t.c.textController.text, '');
      expect(t.platform.disposed.length, 1);
      expect(t.c.status, PlaceAutocompleteStatus.idle);
    });
  });

  test('fetchDetailsOnSelect=false hands the live session to the app', () {
    fakeAsync((async) {
      final platform = FakePlatform();
      final picked = <PlacePrediction>[];
      final c = PlaceAutocompleteController();
      c.attach(
        PlaceAutocompleteConfig(
          api: FlPlaceAutocomplete(platform: platform),
          options: PredictionOptions(),
          fields: defaultPlaceFields,
          fetchDetailsOnSelect: false,
          onPredictionSelected: picked.add,
        ),
      );
      c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      c.select(c.predictions.single);
      async.flushMicrotasks();
      expect(platform.fetchCalls, isEmpty);
      final s = c.takeSession();
      expect(s, isNotNull);
      expect(s!.isEnded, isFalse);
      expect(c.session, isNull);
      expect(picked, hasLength(1));
    });
  });

  test('dispose mid-debounce and mid-request does not throw', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      t.c.dispose();
      async.elapse(debounce * 2);
      async.flushMicrotasks();

      final t2 = setUpController();
      final slow = Completer<List<PlacePrediction>>();
      t2.platform.onFind = (_) => slow.future;
      t2.c.textController.text = 'pizza';
      async.elapse(debounce);
      t2.c.dispose();
      slow.complete([prediction('x')]);
      async.flushMicrotasks();
    });
  });

  test('keyboard highlight wraps and selectHighlighted selects', () {
    fakeAsync((async) {
      final t = setUpController();
      t.platform.onFind = (_) =>
          Future.value([prediction('a'), prediction('b')]);
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.moveHighlight(1);
      t.c.moveHighlight(1);
      expect(t.c.highlightedIndex, 1);
      t.c.moveHighlight(1);
      expect(t.c.highlightedIndex, 0);
      t.c.moveHighlight(-1);
      expect(t.c.highlightedIndex, 1);
      t.c.selectHighlighted();
      async.flushMicrotasks();
      expect(t.platform.fetchCalls.single.placeId, 'b');
    });
  });

  group('Task 7 review follow-ups', () {
    test('M2: typing after an error clears error and retry before notifying', () {
      fakeAsync((async) {
        final t = setUpController();
        t.platform.onFind = (_) => Future.error(
          const PlaceAutocompleteException(
            code: PlaceAutocompleteErrorCode.networkError,
          ),
        );
        t.c.textController.text = 'pizza';
        async.elapse(debounce);
        async.flushMicrotasks();
        expect(t.c.status, PlaceAutocompleteStatus.error);
        final seen = <(PlaceAutocompleteStatus, PlaceAutocompleteException?)>[];
        t.c.addListener(() => seen.add((t.c.status, t.c.error)));
        t.platform.onFind = null;
        t.c.textController.text = 'pizzas';
        expect(seen, isNotEmpty);
        expect(seen.first.$1, isNot(PlaceAutocompleteStatus.error));
        expect(seen.first.$2, isNull);
        expect(t.c.error, isNull);
        final before = t.platform.findCalls.length;
        t.c.retry(); // stale retry must be a no-op
        async.flushMicrotasks();
        expect(t.platform.findCalls.length, before);
        async.elapse(debounce);
        async.flushMicrotasks();
        expect(t.c.status, PlaceAutocompleteStatus.results);
      });
    });

    test('M2: typing below minChars after an error goes idle with no error', () {
      fakeAsync((async) {
        final t = setUpController();
        t.platform.onFind = (_) => Future.error(
          const PlaceAutocompleteException(
            code: PlaceAutocompleteErrorCode.networkError,
          ),
        );
        t.c.textController.text = 'pizza';
        async.elapse(debounce);
        async.flushMicrotasks();
        t.c.textController.text = 'p';
        expect(t.c.status, PlaceAutocompleteStatus.idle);
        expect(t.c.error, isNull);
      });
    });

    test('M3: onFocusLost drops a pending retry', () {
      fakeAsync((async) {
        final t = setUpController();
        t.c.textController.text = 'pizza';
        async.elapse(debounce);
        async.flushMicrotasks();
        t.platform.onFetch = (_) => Future.error(
          const PlaceAutocompleteException(
            code: PlaceAutocompleteErrorCode.networkError,
          ),
        );
        t.c.select(t.c.predictions.single);
        async.flushMicrotasks();
        expect(t.c.status, PlaceAutocompleteStatus.error);
        t.c.onFocusLost();
        async.flushMicrotasks();
        t.platform.onFetch = null;
        t.c.retry();
        async.flushMicrotasks();
        expect(t.platform.fetchCalls.length, 1);
        expect(t.places, isEmpty);
      });
    });

    for (final name in ['clear', 'setText', 'setPlace']) {
      test('M3: $name drops a pending retry', () {
        fakeAsync((async) {
          final t = setUpController();
          t.c.textController.text = 'pizza';
          async.elapse(debounce);
          async.flushMicrotasks();
          t.platform.onFetch = (_) => Future.error(
            const PlaceAutocompleteException(
              code: PlaceAutocompleteErrorCode.networkError,
            ),
          );
          t.c.select(t.c.predictions.single);
          async.flushMicrotasks();
          switch (name) {
            case 'clear':
              t.c.clear();
            case 'setText':
              t.c.setText('x');
            default:
              t.c.setPlace(const Place(id: 'q'));
          }
          t.platform.onFetch = null;
          t.c.retry();
          async.flushMicrotasks();
          expect(t.platform.fetchCalls.length, 1);
          expect(t.places, isEmpty);
        });
      });
    }

    test('M4: an ended session held by the controller is replaced on the next query', () {
      fakeAsync((async) {
        final t = setUpController();
        t.c.textController.text = 'pizza';
        async.elapse(debounce);
        async.flushMicrotasks();
        final s = t.c.session!;
        s.end(); // e.g. the app used controller.session directly
        t.c.textController.text = 'pizzas';
        async.elapse(debounce);
        async.flushMicrotasks();
        expect(t.c.status, PlaceAutocompleteStatus.results);
        expect(t.errors, isEmpty);
        expect(t.platform.findCalls.last.sessionId, isNot(s.id));
        expect(t.c.session!.isEnded, isFalse);
      });
    });

    test('M1: takeSession inside onPredictionSelected returns a live session', () {
      fakeAsync((async) {
        final platform = FakePlatform();
        final api = FlPlaceAutocomplete(platform: platform);
        final c = PlaceAutocompleteController();
        PlaceSession? taken;
        c.attach(
          PlaceAutocompleteConfig(
            api: api,
            options: PredictionOptions(),
            fields: defaultPlaceFields,
            fetchDetailsOnSelect: false,
            onPredictionSelected: (_) => taken = c.takeSession(),
          ),
        );
        c.textController.text = 'pizza';
        async.elapse(debounce);
        async.flushMicrotasks();
        final sid = platform.findCalls.single.sessionId;
        c.select(c.predictions.single);
        c.onFocusLost(); // field blurs right after selection
        async.flushMicrotasks();
        expect(taken, isNotNull);
        expect(taken!.isEnded, isFalse);
        expect(taken!.id, sid);
        expect(platform.disposed, isEmpty);
        api.fetchPlace('pizza-1', session: taken, fields: defaultPlaceFields);
        async.flushMicrotasks();
        expect(platform.fetchCalls.single.sessionId, sid);
      });
    });

    for (final name in ['clear', 'setText']) {
      test('M5: $name during an in-flight select discards the result', () {
        fakeAsync((async) {
          final t = setUpController();
          t.c.textController.text = 'pizza';
          async.elapse(debounce);
          async.flushMicrotasks();
          final fetch = Completer<Place>();
          t.platform.onFetch = (_) => fetch.future;
          t.c.select(t.c.predictions.single);
          async.flushMicrotasks();
          if (name == 'clear') {
            t.c.clear();
          } else {
            t.c.setText('other');
          }
          fetch.complete(const Place(id: 'pizza-1'));
          async.flushMicrotasks();
          expect(t.places, isEmpty);
          expect(t.c.selectedPlace, isNull);
          expect(t.platform.disposed.length, 1);
          expect(t.c.session, isNull);
        });
      });
    }

    test('M5: a throwing disposeSession does not crash', () {
      fakeAsync((async) {
        final t = setUpController();
        t.platform.disposeError = StateError('native boom');
        t.c.textController.text = 'pizza';
        async.elapse(debounce);
        async.flushMicrotasks();
        t.c.onFocusLost();
        async.flushMicrotasks();
        t.c.textController.text = 'tacos';
        async.elapse(debounce);
        async.flushMicrotasks();
        t.c.clear();
        async.flushMicrotasks();
        t.c.textController.text = 'sushi';
        async.elapse(debounce);
        async.flushMicrotasks();
        t.c.dispose();
        async.flushMicrotasks();
        expect(t.platform.disposed.length, 3);
      });
    });

    test('M5: typing during an in-flight select discards the result and keeps sessions usable', () {
      fakeAsync((async) {
        final t = setUpController();
        t.c.textController.text = 'pizza';
        async.elapse(debounce);
        async.flushMicrotasks();
        final s = t.c.session!;
        final fetch = Completer<Place>();
        t.platform.onFetch = (_) => fetch.future;
        t.c.select(t.c.predictions.single);
        async.flushMicrotasks();
        t.c.textController.text = 'pizza margherita';
        // debounce fires while the fetch is still pending: reuses the live session
        async.elapse(debounce);
        async.flushMicrotasks();
        expect(t.errors, isEmpty);
        expect(t.c.status, PlaceAutocompleteStatus.results);
        expect(t.platform.findCalls.last.sessionId, s.id);
        fetch.complete(const Place(id: 'pizza-1'));
        async.flushMicrotasks();
        expect(t.places, isEmpty);
        expect(t.c.selectedPlace, isNull);
        // the fetch ended s; the next query must start a fresh live session
        t.c.textController.text = 'pizza margherita x';
        async.elapse(debounce);
        async.flushMicrotasks();
        expect(t.errors, isEmpty);
        expect(t.c.status, PlaceAutocompleteStatus.results);
        expect(t.platform.findCalls.last.sessionId, isNot(s.id));
        t.platform.onFetch = null;
        t.c.select(t.c.predictions.single);
        async.flushMicrotasks();
        expect(t.places.single.id, 'pizza margherita x-1');
      });
    });
  });
}
