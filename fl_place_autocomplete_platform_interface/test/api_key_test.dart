import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePlacesApiKey', () {
    test('platform-specific key beats the generic one', () {
      expect(
        resolvePlacesApiKey(
          platform: PlacesApiPlatform.android,
          generic: 'g',
          android: 'a',
          ios: null,
          web: null,
        ),
        'a',
      );
    });

    test('generic key is used when the specific one is blank', () {
      for (final blank in [null, '', '   ', '\t\n']) {
        expect(
          resolvePlacesApiKey(
            platform: PlacesApiPlatform.ios,
            generic: 'g',
            android: null,
            ios: blank,
            web: null,
          ),
          'g',
          reason: 'specific=${blank == null ? 'null' : '"$blank"'}',
        );
      }
    });

    test('null when neither is set (blank/whitespace ignored)', () {
      expect(
        resolvePlacesApiKey(
          platform: PlacesApiPlatform.web,
          generic: '  ',
          android: null,
          ios: null,
          web: '',
        ),
        isNull,
      );
      expect(
        resolvePlacesApiKey(
          platform: PlacesApiPlatform.web,
          generic: '',
          android: 'a',
          ios: 'i',
          web: null,
        ),
        isNull,
      );
    });

    test('keys are trimmed', () {
      expect(
        resolvePlacesApiKey(
          platform: PlacesApiPlatform.web,
          generic: ' g ',
          android: null,
          ios: null,
          web: null,
        ),
        'g',
      );
    });

    test('each platform selects its own override', () {
      String? pick(PlacesApiPlatform p) => resolvePlacesApiKey(
        platform: p,
        generic: 'g',
        android: 'a',
        ios: 'i',
        web: 'w',
      );
      expect(pick(PlacesApiPlatform.android), 'a');
      expect(pick(PlacesApiPlatform.ios), 'i');
      expect(pick(PlacesApiPlatform.web), 'w');
    });

    test('defaults are the (empty in tests) compile-time defines', () {
      expect(resolvePlacesApiKey(platform: PlacesApiPlatform.android), isNull);
      expect(genericPlacesApiKey(), isNull);
      expect(genericPlacesApiKey(generic: ' k '), 'k');
    });
  });
}
