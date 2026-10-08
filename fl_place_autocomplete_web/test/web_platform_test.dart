@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_web/fl_place_autocomplete_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Installs a fake `google.maps` that records calls on `window.__calls`.
///
/// Knobs: `window.__failFetch` (number of upcoming `fetchFields` calls to
/// reject) and `window.__rejectSuggest` (message to reject suggestions with).
void installStub() {
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.text = '''
    window.__calls = [];
    window.__failFetch = 0;
    window.__rejectSuggest = null;
    class Token { constructor(){ this.n = (window.__tokens = (window.__tokens||0)+1); } }
    class Place {
      constructor(init){ this.init = init; this.viaPrediction = false; }
      async fetchFields(o){
        window.__calls.push({fn:'fetchFields', fields:o.fields, viaPrediction:this.viaPrediction,
          id:this.init.id, token:this.token&&this.token.n,
          requestedLanguage:this.init.requestedLanguage, requestedRegion:this.init.requestedRegion});
        if (window.__failFetch > 0) { window.__failFetch--; throw new Error('Failed to fetch: network down'); }
        if (o.fields.includes('photos')) {
          this.photos = [{widthPx:400, heightPx:300, getURI(opts){
            window.__calls.push({fn:'getURI', maxWidth:opts.maxWidth, maxHeight:opts.maxHeight});
            return 'https://photo.test/p?w=' + opts.maxWidth + '&h=' + opts.maxHeight;
          }}];
        }
      }
      toJSON(){
        const j = {id:this.init.id, displayName:'N', location:{lat:1,lng:2}};
        if (this.photos) j.photos = this.photos.map(p => ({widthPx:p.widthPx, heightPx:p.heightPx,
          authorAttributions:[{displayName:'Ann'}]}));
        return j;
      }
    }
    window.__google = { maps: { importLibrary: async (n) => ({
      AutocompleteSessionToken: Token,
      Place,
      AutocompleteSuggestion: { fetchAutocompleteSuggestions: async (req) => {
        window.__calls.push({fn:'suggest', input:req.input, token:req.sessionToken && req.sessionToken.n,
          language:req.language, region:req.region});
        if (window.__rejectSuggest) throw new Error(window.__rejectSuggest);
        return { suggestions: [ { placePrediction: {
          placeId: 'p1', text:{text:'A, B', matches:[{startOffset:0,endOffset:1}]},
          mainText:{text:'A'}, secondaryText:{text:'B'}, types:['x'],
          toPlace(){ const p = new Place({id:'p1'}); p.viaPrediction = true; p.token = req.sessionToken; return p; } } } ] };
      } },
    }) } };
    window.google = window.__google;
  ''';
  web.document.head!.append(script);
}

JSObject get _window => web.window as JSObject;

List<Map<Object?, Object?>> _calls([String? fn]) => [
  for (final c
      in _window.getProperty<JSAny?>('__calls'.toJS).dartify()! as List)
    if (fn == null || (c as Map)['fn'] == fn) c as Map<Object?, Object?>,
];

void main() {
  setUpAll(installStub);

  setUp(() {
    _window.setProperty('__calls'.toJS, JSArray<JSAny>());
    _window.setProperty('__failFetch'.toJS, 0.toJS);
    _window.setProperty('__rejectSuggest'.toJS, null);
    _window.setProperty('google'.toJS, _window.getProperty('__google'.toJS));
  });

  test(
    'prediction + fetch in one session uses toPlace() and the same token',
    () async {
      final platform = FlPlaceAutocompleteWeb();
      final preds = await platform.findPredictions(
        'pi',
        sessionId: 's',
        options: PredictionOptions(),
      );
      expect(preds.single.placeId, 'p1');
      expect(preds.single.fullText, 'A, B');
      expect(preds.single.primaryText, 'A');
      expect(preds.single.secondaryText, 'B');
      expect(preds.single.matchedRanges.map((r) => (r.start, r.end)), [(0, 1)]);
      expect(preds.single.types, ['x']);
      await platform.findPredictions(
        'piz',
        sessionId: 's',
        options: PredictionOptions(),
      );
      final place = await platform.fetchPlace(
        'p1',
        sessionId: 's',
        fields: {PlaceField.location},
      );
      expect(place.location, const LatLng(1, 2));
      final calls = _window
          .getProperty<JSArray<JSObject>>('__calls'.toJS)
          .toDart;
      final tokens = calls
          .map((c) => c.getProperty<JSAny?>('token'.toJS)?.dartify())
          .whereType<num>()
          .toSet();
      expect(tokens.length, 1);
      final fetch = calls.last;
      expect(fetch.getProperty<JSBoolean>('viaPrediction'.toJS).toDart, isTrue);
      expect(_calls('fetchFields').single['fields'], ['location']);
    },
  );

  test('without a session no token is sent', () async {
    final platform = FlPlaceAutocompleteWeb();
    await platform.findPredictions('pi', options: PredictionOptions());
    expect(_calls('suggest').single['token'], isNull);
  });

  test(
    'without a cached prediction it falls back to a bare Place and warns',
    () async {
      final platform = FlPlaceAutocompleteWeb();
      final place = await platform.fetchPlace(
        'unknown',
        fields: {PlaceField.id},
      );
      expect(place.id, 'unknown');
      expect(_calls('fetchFields').single['viaPrediction'], isFalse);
    },
  );

  test('disposeSession drops cached state', () async {
    final platform = FlPlaceAutocompleteWeb();
    await platform.findPredictions(
      'pi',
      sessionId: 'd',
      options: PredictionOptions(),
    );
    await platform.disposeSession('d');
    final place = await platform.fetchPlace(
      'p1',
      sessionId: 'd',
      fields: {PlaceField.id},
    );
    expect(place.id, 'p1'); // fell back to bare Place
    expect(_calls('fetchFields').single['viaPrediction'], isFalse);
  });

  test('a successful fetch ends the session', () async {
    final platform = FlPlaceAutocompleteWeb();
    await platform.findPredictions(
      'pi',
      sessionId: 'e',
      options: PredictionOptions(),
    );
    await platform.fetchPlace('p1', sessionId: 'e', fields: {PlaceField.id});
    await platform.fetchPlace('p1', sessionId: 'e', fields: {PlaceField.id});
    expect(_calls('fetchFields').map((c) => c['viaPrediction']), [true, false]);
  });

  test(
    'a failed fetchFields keeps the session so a retry still uses toPlace()',
    () async {
      final platform = FlPlaceAutocompleteWeb();
      await platform.findPredictions(
        'pi',
        sessionId: 'f',
        options: PredictionOptions(),
      );
      _window.setProperty('__failFetch'.toJS, 1.toJS);
      await expectLater(
        platform.fetchPlace('p1', sessionId: 'f', fields: {PlaceField.id}),
        throwsA(
          isA<PlaceAutocompleteException>()
              .having(
                (e) => e.code,
                'code',
                PlaceAutocompleteErrorCode.networkError,
              )
              .having((e) => e.message, 'message', contains('Failed to fetch')),
        ),
      );
      final place = await platform.fetchPlace(
        'p1',
        sessionId: 'f',
        fields: {PlaceField.id},
      );
      expect(place.id, 'p1');
      final fetches = _calls('fetchFields');
      expect(fetches.map((c) => c['viaPrediction']), [true, true]);
      expect(fetches[0]['token'], isNotNull);
      expect(fetches[1]['token'], fetches[0]['token']);
    },
  );

  test(
    'passes language and region on the suggestion request and the bare Place',
    () async {
      final platform = FlPlaceAutocompleteWeb();
      await platform.findPredictions(
        'pi',
        options: PredictionOptions(languageCode: 'fr', regionCode: 'ca'),
      );
      final suggest = _calls('suggest').single;
      expect(suggest['language'], 'fr');
      expect(suggest['region'], 'ca');
      await platform.fetchPlace(
        'x',
        fields: {PlaceField.id},
        languageCode: 'de',
        regionCode: 'at',
      );
      final fetch = _calls('fetchFields').single;
      expect(fetch['requestedLanguage'], 'de');
      expect(fetch['requestedRegion'], 'at');
    },
  );

  test('missing google.maps throws invalidApiKey with a setup hint', () async {
    _window.delete('google'.toJS);
    final platform = FlPlaceAutocompleteWeb();
    await expectLater(
      platform.findPredictions('pi', options: PredictionOptions()),
      throwsA(
        isA<PlaceAutocompleteException>()
            .having(
              (e) => e.code,
              'code',
              PlaceAutocompleteErrorCode.invalidApiKey,
            )
            .having((e) => e.message, 'message', contains('web/index.html')),
      ),
    );
    await expectLater(
      platform.fetchPlace('p1', fields: {PlaceField.id}),
      throwsA(
        isA<PlaceAutocompleteException>().having(
          (e) => e.code,
          'code',
          PlaceAutocompleteErrorCode.invalidApiKey,
        ),
      ),
    );
  });

  test(
    'a JS rejection maps to a PlaceAutocompleteException with the JS message',
    () async {
      _window.setProperty(
        '__rejectSuggest'.toJS,
        'OVER_QUERY_LIMIT: quota exceeded'.toJS,
      );
      final platform = FlPlaceAutocompleteWeb();
      await expectLater(
        platform.findPredictions('pi', options: PredictionOptions()),
        throwsA(
          isA<PlaceAutocompleteException>()
              .having(
                (e) => e.code,
                'code',
                PlaceAutocompleteErrorCode.quotaExceeded,
              )
              .having(
                (e) => e.message,
                'message',
                contains('OVER_QUERY_LIMIT'),
              ),
        ),
      );
    },
  );

  test(
    'fetchPhoto returns the getURI result for a photo from fetchPlace',
    () async {
      final platform = FlPlaceAutocompleteWeb();
      final place = await platform.fetchPlace(
        'ph',
        fields: {PlaceField.id, PlaceField.photos},
      );
      final ref = place.photos!.single;
      expect(ref.id, 'ph#0');
      expect(ref.widthPx, 400);
      expect(ref.authorAttributions.single.displayName, 'Ann');
      final photo = await platform.fetchPhoto(
        ref,
        maxWidth: 200,
        maxHeight: 100,
      );
      expect(photo.uri, 'https://photo.test/p?w=200&h=100');
      expect(_calls('getURI').single, {
        'fn': 'getURI',
        'maxWidth': 200,
        'maxHeight': 100,
      });
    },
  );

  test('fetchPhoto with an unknown id throws notFound', () async {
    final platform = FlPlaceAutocompleteWeb();
    await expectLater(
      platform.fetchPhoto(const PlacePhotoRef(id: 'nope#0')),
      throwsA(
        isA<PlaceAutocompleteException>().having(
          (e) => e.code,
          'code',
          PlaceAutocompleteErrorCode.notFound,
        ),
      ),
    );
  });

  test('registerWith installs the web platform', () {
    FlPlaceAutocompleteWeb.registerWith(webPluginRegistrar);
    expect(FlPlaceAutocompletePlatform.instance, isA<FlPlaceAutocompleteWeb>());
  });
}
