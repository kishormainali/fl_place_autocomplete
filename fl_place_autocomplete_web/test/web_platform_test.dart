@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_web/fl_place_autocomplete_web.dart';
import 'package:fl_place_autocomplete_web/src/loader_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Installs a fake `google.maps` that records calls on `window.__calls`.
///
/// Knobs: `window.__failFetch` (number of upcoming `fetchFields` calls to
/// reject), `window.__rejectSuggest` (message to reject suggestions with),
/// `window.__holdSuggest` (suggestions wait for `window.__releaseSuggest()`)
/// and `window.__instances` (Place exposes class instances with prototype
/// getters/methods and no own enumerable props, like the real Maps JS API).
///
/// `fetchFields` rejects field names the real `Place` class does not have.
void installStub() {
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.text = '''
    window.__calls = [];
    window.__failFetch = 0;
    window.__rejectSuggest = null;
    window.__holdSuggest = false;
    window.__instances = false;
    const KNOWN = ['id','displayName','formattedAddress','shortFormattedAddress','location',
      'viewport','addressComponents','types','primaryType','primaryTypeDisplayName','rating',
      'userRatingCount','priceLevel','nationalPhoneNumber','internationalPhoneNumber','websiteURI',
      'googleMapsURI','utcOffsetMinutes','businessStatus','editorialSummary','regularOpeningHours',
      'photos','reviews'];
    class LatLngC { #a; #b; constructor(a,b){ this.#a=a; this.#b=b; }
      lat(){ return this.#a; } lng(){ return this.#b; } toJSON(){ return {lat:this.#a, lng:this.#b}; } }
    class BoundsC { #sw; #ne; constructor(sw,ne){ this.#sw=sw; this.#ne=ne; }
      getSouthWest(){ return this.#sw; } getNorthEast(){ return this.#ne; } }
    class AuthorC { #n; constructor(n){ this.#n=n; }
      get displayName(){ return this.#n; } get uri(){ return 'https://a.test'; } get photoURI(){ return 'https://p.test'; } }
    class PhotoC { #w; #h; constructor(w,h){ this.#w=w; this.#h=h; }
      get widthPx(){ return this.#w; } get heightPx(){ return this.#h; }
      get authorAttributions(){ return [new AuthorC('Ann')]; }
      getURI(opts){ return 'https://photo.test/i?w=' + opts.maxWidth; } }
    class ReviewC {
      get rating(){ return 4; } get text(){ return 'nice'; }
      get relativePublishTimeDescription(){ return 'a week ago'; }
      get publishTime(){ return new Date(Date.UTC(2024,0,2,3,4,5)); }
      get authorAttribution(){ return new AuthorC('Rev'); }
      toJSON(){ return {rating:this.rating, text:this.text, publishTime:this.publishTime,
        authorAttribution:this.authorAttribution}; } }
    class Token { constructor(){ this.n = (window.__tokens = (window.__tokens||0)+1); } }
    class Place {
      constructor(init){ this.init = init; this.viaPrediction = false; }
      async fetchFields(o){
        window.__calls.push({fn:'fetchFields', fields:o.fields, viaPrediction:this.viaPrediction,
          id:this.init.id, token:this.token&&this.token.n,
          requestedLanguage:this.init.requestedLanguage, requestedRegion:this.init.requestedRegion});
        if (window.__failFetch > 0) { window.__failFetch--; throw new Error('Failed to fetch: network down'); }
        for (const f of o.fields) if (!KNOWN.includes(f)) throw new Error('InvalidValueError: unknown field ' + f);
        if (window.__instances) {
          this.location = new LatLngC(1.5, 2.5);
          this.viewport = new BoundsC(new LatLngC(0, 1), new LatLngC(2, 3));
          this.photos = [new PhotoC(640, 480)];
          this.reviews = [new ReviewC()];
          return;
        }
        if (o.fields.includes('photos')) {
          this.photos = [{widthPx:400, heightPx:300, getURI(opts){
            window.__calls.push({fn:'getURI', maxWidth:opts.maxWidth, maxHeight:opts.maxHeight});
            return 'https://photo.test/p?w=' + opts.maxWidth + '&h=' + opts.maxHeight;
          }}];
        }
      }
      toJSON(){
        if (window.__instances) return {id:this.init.id, location:this.location, viewport:this.viewport,
          photos:this.photos, reviews:this.reviews};
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
        if (window.__holdSuggest) await new Promise(r => { window.__releaseSuggest = r; });
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
    _window.setProperty('__holdSuggest'.toJS, false.toJS);
    _window.setProperty('__instances'.toJS, false.toJS);
    _window.setProperty('google'.toJS, _window.getProperty('__google'.toJS));
    web.document.querySelector('script#$mapsLoaderScriptId')?.remove();
  });

  int loaderScripts() =>
      web.document.querySelectorAll('script#$mapsLoaderScriptId').length;

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

  test('missing google.maps and no key throws invalidApiKey listing all '
      'three options', () async {
    _window.delete('google'.toJS);
    // No defines in tests, so the default constructor has no key either.
    for (final platform in [
      FlPlaceAutocompleteWeb(),
      FlPlaceAutocompleteWeb(apiKey: ' '),
    ]) {
      await expectLater(
        platform.findPredictions('pi', options: PredictionOptions()),
        throwsA(
          isA<PlaceAutocompleteException>()
              .having(
                (e) => e.code,
                'code',
                PlaceAutocompleteErrorCode.invalidApiKey,
              )
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('GOOGLE_PLACES_API_KEY_WEB'),
                  contains('--dart-define=GOOGLE_PLACES_API_KEY='),
                  contains('web/index.html'),
                ),
              ),
        ),
      );
    }
    expect(loaderScripts(), 0);
    final platform = FlPlaceAutocompleteWeb();
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

  group('final review fixes', () {
    test('fetchFields receives the JS Place field names', () async {
      final platform = FlPlaceAutocompleteWeb();
      await platform.fetchPlace('all', fields: PlaceField.values.toSet());
      final sent = _calls('fetchFields').single['fields']! as List;
      expect(sent, hasLength(23));
      expect(sent, containsAll(['websiteURI', 'googleMapsURI']));
      expect(sent, isNot(contains('websiteUri')));
      expect(sent, isNot(contains('googleMapsUri')));
    });

    test(
      'location, viewport, photos and reviews map from class instances',
      () async {
        _window.setProperty('__instances'.toJS, true.toJS);
        final platform = FlPlaceAutocompleteWeb();
        final place = await platform.fetchPlace(
          'inst',
          fields: {
            PlaceField.id,
            PlaceField.location,
            PlaceField.viewport,
            PlaceField.photos,
            PlaceField.reviews,
          },
        );
        expect(place.id, 'inst');
        expect(place.location, const LatLng(1.5, 2.5));
        expect(place.viewport!.southwest, const LatLng(0, 1));
        expect(place.viewport!.northeast, const LatLng(2, 3));
        final photo = place.photos!.single;
        expect(photo.widthPx, 640);
        expect(photo.heightPx, 480);
        expect(photo.authorAttributions.single.displayName, 'Ann');
        expect(photo.authorAttributions.single.photoUri, 'https://p.test');
        final review = place.reviews!.single;
        expect(review.rating, 4.0);
        expect(review.text, 'nice');
        expect(review.relativePublishTimeDescription, 'a week ago');
        expect(review.publishTime, '2024-01-02T03:04:05.000Z');
        expect(review.authorAttribution!.displayName, 'Rev');
        expect(review.authorAttribution!.uri, 'https://a.test');
        final uri = await platform.fetchPhoto(photo, maxWidth: 99);
        expect(uri.uri, 'https://photo.test/i?w=99');
      },
    );

    test(
      'a late findPredictions response does not recreate an ended session',
      () async {
        _window.setProperty('__holdSuggest'.toJS, true.toJS);
        final platform = FlPlaceAutocompleteWeb();
        final pending = platform.findPredictions(
          'pi',
          sessionId: 'late',
          options: PredictionOptions(),
        );
        // let the request reach the stub
        while (_calls('suggest').isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        await platform.disposeSession('late');
        _window.callMethod<JSAny?>('__releaseSuggest'.toJS);
        await pending;
        await platform.fetchPlace(
          'p1',
          sessionId: 'late',
          fields: {PlaceField.id},
        );
        expect(_calls('fetchFields').single['viaPrediction'], isFalse);
      },
    );

    test(
      'a legacy loader without importLibrary throws invalidApiKey with a hint',
      () async {
        _window.setProperty(
          'google'.toJS,
          <String, Object?>{'maps': <String, Object?>{}}.jsify(),
        );
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
                .having((e) => e.message, 'message', contains('importLibrary'))
                .having(
                  (e) => e.message,
                  'message',
                  contains('web/index.html'),
                ),
          ),
        );
      },
    );
  });

  group('API key loader', () {
    test('with a key and no google.maps, injects the loader once and '
        'then uses the library', () async {
      _window.delete('google'.toJS);
      final built = <String>[];
      final platform = FlPlaceAutocompleteWeb(
        apiKey: 'dart-key',
        loaderSource: (key) {
          built.add(key);
          return 'window.google = window.__google;';
        },
      );
      final preds = await platform.findPredictions(
        'pi',
        options: PredictionOptions(),
      );
      expect(preds.single.placeId, 'p1');
      await platform.findPredictions('pa', options: PredictionOptions());
      expect(built, ['dart-key']);
      expect(loaderScripts(), 1);
      // A second platform instance sees google.maps and does not inject.
      await FlPlaceAutocompleteWeb(
        apiKey: 'dart-key',
        loaderSource: (key) => throw StateError('must not inject'),
      ).findPredictions('pe', options: PredictionOptions());
      expect(loaderScripts(), 1);
    });

    test('never injects when google.maps is already loaded', () async {
      final platform = FlPlaceAutocompleteWeb(
        apiKey: 'dart-key',
        loaderSource: (key) => throw StateError('must not inject'),
      );
      await platform.findPredictions('pi', options: PredictionOptions());
      expect(loaderScripts(), 0);
    });
  });
}
