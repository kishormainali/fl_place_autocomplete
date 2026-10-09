@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:fl_place_autocomplete_web/src/js_places.dart';
import 'package:fl_place_autocomplete_web/src/loader_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

JSObject get _window => web.window as JSObject;

List<web.Element> _loaderScripts() {
  final found = web.document.querySelectorAll('script#$mapsLoaderScriptId');
  return [for (var i = 0; i < found.length; i++) found.item(i)! as web.Element];
}

/// Runs [source] as an inline script, like the browser would.
void _run(String source) {
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.text = source;
  // appendChild, not append: one test stubs head.append.
  web.document.head!.appendChild(script);
  script.remove();
}

void main() {
  setUp(() {
    _window.delete('google'.toJS);
    for (final s in _loaderScripts()) {
      s.remove();
    }
  });

  group('buildLoaderSource', () {
    test('embeds the key and version as JSON string literals', () {
      final src = buildLoaderSource('a"b', version: 'beta');
      expect(src, contains(r'key: "a\"b"'));
      expect(src, contains('v: "beta"'));
      expect(src, contains('importLibrary'));
    });

    test('a key with quotes, backslashes and </script> reaches the Maps '
        'URL unchanged and injects nothing else', () async {
      const nasty =
          r'k"e\y'
          "'</script><b> x";
      // Capture the script the bootstrap appends instead of loading it.
      _run('''
        window.__appended = [];
        window.__origAppend = document.head.append;
        document.head.append = function (el) { window.__appended.push(el.src); };
      ''');
      addTearDown(() => _run('document.head.append = window.__origAppend;'));
      _run(buildLoaderSource(nasty));
      final maps = (_window['google']! as JSObject)['maps']! as JSObject;
      expect(isFunction(maps, 'importLibrary'), isTrue);
      // Never resolves (the real script is not loaded); only triggers append.
      maps.callMethod<JSAny?>('importLibrary'.toJS, 'places'.toJS);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final appended =
          _window.getProperty<JSAny?>('__appended'.toJS).dartify()! as List;
      expect(appended, hasLength(1));
      final url = Uri.parse(appended.single as String);
      expect(url.host, 'maps.googleapis.com');
      expect(url.queryParameters['key'], nasty);
      expect(url.queryParameters['v'], 'weekly');
      expect(url.queryParameters['libraries'], 'places');
    });
  });

  group('ensureMapsLoader', () {
    test('injects the bootstrap exactly once when google.maps is absent '
        'and a key is given', () {
      expect(ensureMapsLoader('key'), isTrue);
      expect(ensureMapsLoader('key'), isFalse);
      expect(_loaderScripts(), hasLength(1));
      final maps = (_window['google']! as JSObject)['maps']! as JSObject;
      expect(isFunction(maps, 'importLibrary'), isTrue);
    });

    test('does not inject twice even if the bootstrap did not define '
        'google.maps (e.g. blocked by CSP)', () {
      expect(ensureMapsLoader('key', source: (_) => '/* blocked */'), isTrue);
      expect(ensureMapsLoader('key', source: (_) => '/* blocked */'), isFalse);
      expect(_loaderScripts(), hasLength(1));
    });

    test('never injects when google.maps already exists', () {
      _window['google'] = <String, Object?>{'maps': <String, Object?>{}}
          .jsify();
      expect(ensureMapsLoader('key'), isFalse);
      expect(_loaderScripts(), isEmpty);
    });

    test('never injects without a key', () {
      for (final key in [null, '', '  ']) {
        expect(ensureMapsLoader(key), isFalse);
      }
      expect(_loaderScripts(), isEmpty);
      expect(_window['google'], isNull);
    });
  });

  group('loadPlacesLibrary', () {
    test('no google.maps and no key -> MapsApiMissing listing all three '
        'options', () async {
      await expectLater(
        loadPlacesLibrary(null),
        throwsA(
          isA<MapsApiMissing>()
              .having((e) => e.legacyLoader, 'legacyLoader', isFalse)
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('--dart-define=GOOGLE_PLACES_API_KEY_WEB='),
                  contains('--dart-define=GOOGLE_PLACES_API_KEY='),
                  contains('web/index.html'),
                ),
              ),
        ),
      );
      expect(_loaderScripts(), isEmpty);
    });

    test('injects with a key, then imports the places library', () async {
      final lib = await loadPlacesLibrary(
        'key',
        source: (key) =>
            'window.google = {maps: {importLibrary: async (n) => '
            '({lib: n, key: ${'"$key"'}})}};',
      );
      expect(lib.getProperty<JSString>('lib'.toJS).toDart, 'places');
      expect(lib.getProperty<JSString>('key'.toJS).toDart, 'key');
      expect(_loaderScripts(), hasLength(1));
    });

    test('a bootstrap that defines nothing -> MapsApiMissing', () async {
      await expectLater(
        loadPlacesLibrary('key', source: (_) => '/* blocked */'),
        throwsA(isA<MapsApiMissing>()),
      );
    });
  });
}
