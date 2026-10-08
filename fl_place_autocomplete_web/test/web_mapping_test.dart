import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_web/src/web_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('request omits nulls and maps circle bias, origin and language', () {
    final r = requestFromOptions(
      'pi',
      PredictionOptions(
        locationBias: const CircularArea(
          center: LatLng(1, 2),
          radiusMeters: 500,
        ),
        origin: const LatLng(3, 4),
        includedRegionCodes: ['us'],
        languageCode: 'en',
        regionCode: 'us',
      ),
    );
    expect(r['input'], 'pi');
    expect(r['locationBias'], {
      'center': {'lat': 1.0, 'lng': 2.0},
      'radius': 500.0,
    });
    expect(r['origin'], {'lat': 3.0, 'lng': 4.0});
    expect(r['includedRegionCodes'], ['us']);
    expect(r['language'], 'en');
    expect(r['region'], 'us');
    expect(r.containsKey('locationRestriction'), isFalse);
    expect(r.containsKey('includedPrimaryTypes'), isFalse);
  });
  test('request maps rectangle restriction', () {
    final r = requestFromOptions(
      'x',
      PredictionOptions(
        locationRestriction: const LatLngBounds(
          southwest: LatLng(0, 1),
          northeast: LatLng(2, 3),
        ),
      ),
    );
    expect(r['locationRestriction'], {
      'south': 0.0,
      'west': 1.0,
      'north': 2.0,
      'east': 3.0,
    });
  });
  test('request maps rectangle bias and inputOffset', () {
    final r = requestFromOptions(
      'x',
      PredictionOptions(
        locationBias: const RectangularArea(
          LatLngBounds(southwest: LatLng(0, 1), northeast: LatLng(2, 3)),
        ),
        includedPrimaryTypes: ['cafe'],
        inputOffset: 2,
      ),
    );
    expect(r['locationBias'], {
      'south': 0.0,
      'west': 1.0,
      'north': 2.0,
      'east': 3.0,
    });
    expect(r['includedPrimaryTypes'], ['cafe']);
    expect(r['inputOffset'], 2);
  });
  test('prediction maps matches and tolerates missing secondary text', () {
    final p = predictionFromWeb({
      'placeId': 'p',
      'text': 'A, B',
      'mainText': 'A',
      'secondaryText': null,
      'types': ['x'],
      'distanceMeters': 7,
      'matches': [
        {'startOffset': 0, 'endOffset': 1},
      ],
    });
    expect(p.secondaryText, '');
    expect(p.matchedRanges.single.end, 1);
    expect(p.distanceMeters, 7);
  });
  test(
    'prediction passes non-BMP offsets through and tolerates absent data',
    () {
      final p = predictionFromWeb({
        'placeId': 'p',
        'text': '\u{1F600}ab',
        'mainText': '\u{1F600}ab',
        'matches': [
          {'startOffset': 0, 'endOffset': 3},
        ],
      });
      expect(p.matchedRanges.single.start, 0);
      expect(p.matchedRanges.single.end, 3);
      expect(p.types, isEmpty);
      expect(p.distanceMeters, isNull);
      expect(p.secondaryText, '');
      final q = predictionFromWeb({'placeId': 'q'});
      expect(q.fullText, '');
      expect(q.matchedRanges, isEmpty);
    },
  );
  test('place maps toJSON shape', () {
    final place = placeFromWebJson({
      'id': 'p',
      'displayName': 'N',
      'location': {'lat': 1.5, 'lng': 2.5},
      'viewport': {'south': 0, 'west': 1, 'north': 2, 'east': 3},
      'priceLevel': 'VERY_EXPENSIVE',
      'businessStatus': 'CLOSED_TEMPORARILY',
      'websiteURI': 'https://x.dev',
      'regularOpeningHours': {
        'weekdayDescriptions': ['Mon'],
        'periods': [
          {
            'open': {'day': 1, 'hour': 9, 'minute': 0},
          },
        ],
      },
      'photos': [
        {
          'widthPx': 10,
          'heightPx': 20,
          'authorAttributions': [
            {'displayName': 'N'},
          ],
        },
      ],
    }, photoIdFor: (i) => 'ph$i');
    expect(place.location, const LatLng(1.5, 2.5));
    expect(place.viewport!.northeast, const LatLng(2, 3));
    expect(place.priceLevel, PriceLevel.veryExpensive);
    expect(place.businessStatus, BusinessStatus.closedTemporarily);
    expect(place.photos!.single.id, 'ph0');
    expect(place.regularOpeningHours!.periods.single.open!.hour, 9);
    expect(place.reviews, isNull);
  });
  test('place maps reviews with author attributions', () {
    final place = placeFromWebJson({
      'reviews': [
        {
          'rating': 4,
          'text': 'nice',
          'relativePublishTimeDescription': 'a week ago',
          'publishTime': '2024-01-01T00:00:00Z',
          'authorAttribution': {
            'displayName': 'A',
            'uri': 'https://a',
            'photoURI': 'https://p',
          },
        },
        {
          'authorAttribution': {'photoUri': 'https://q'},
        },
        <Object?, Object?>{},
      ],
    }, photoIdFor: (i) => 'x');
    final r = place.reviews!;
    expect(r, hasLength(3));
    expect(r[0].rating, 4.0);
    expect(r[0].text, 'nice');
    expect(r[0].relativePublishTimeDescription, 'a week ago');
    expect(r[0].publishTime, '2024-01-01T00:00:00Z');
    expect(r[0].authorAttribution!.displayName, 'A');
    expect(r[0].authorAttribution!.uri, 'https://a');
    expect(r[0].authorAttribution!.photoUri, 'https://p');
    expect(r[1].authorAttribution!.photoUri, 'https://q');
    expect(r[2].authorAttribution, isNull);
  });
  test('place accepts both key spellings and PRICE_LEVEL_ prefix', () {
    final a = placeFromWebJson({
      'websiteUri': 'https://a.dev',
      'googleMapsUri': 'https://m.dev',
      'priceLevel': 'PRICE_LEVEL_VERY_EXPENSIVE',
    }, photoIdFor: (i) => 'x');
    expect(a.websiteUri, Uri.parse('https://a.dev'));
    expect(a.googleMapsUri, Uri.parse('https://m.dev'));
    expect(a.priceLevel, PriceLevel.veryExpensive);
    final b = placeFromWebJson({
      'websiteURI': 'https://b.dev',
      'googleMapsURI': 'https://n.dev',
      'priceLevel': 'FREE',
    }, photoIdFor: (i) => 'x');
    expect(b.websiteUri, Uri.parse('https://b.dev'));
    expect(b.googleMapsUri, Uri.parse('https://n.dev'));
    expect(b.priceLevel, PriceLevel.free);
  });
  test('place maps scalars and address components', () {
    final place = placeFromWebJson({
      'rating': 4,
      'userRatingCount': 12,
      'utcOffsetMinutes': 60,
      'types': ['a', 'b'],
      'primaryType': 'a',
      'editorialSummary': 'e',
      'addressComponents': [
        {
          'longText': 'L',
          'shortText': 'S',
          'types': ['route'],
        },
        <Object?, Object?>{},
      ],
    }, photoIdFor: (i) => 'x');
    expect(place.rating, 4.0);
    expect(place.userRatingCount, 12);
    expect(place.utcOffsetMinutes, 60);
    expect(place.types, ['a', 'b']);
    expect(place.editorialSummary, 'e');
    expect(place.addressComponents![0].types, ['route']);
    expect(place.addressComponents![1].types, isEmpty);
  });
  test('absent optional data stays null and never throws', () {
    final place = placeFromWebJson(
      <Object?, Object?>{},
      photoIdFor: (i) => 'x',
    );
    expect(place.id, isNull);
    expect(place.location, isNull);
    expect(place.viewport, isNull);
    expect(place.photos, isNull);
    expect(place.reviews, isNull);
    expect(place.types, isNull);
    expect(place.addressComponents, isNull);
    expect(place.priceLevel, isNull);
    expect(place.businessStatus, isNull);
    expect(place.websiteUri, isNull);
    expect(place.regularOpeningHours, isNull);
    final nulls = placeFromWebJson({
      'location': null,
      'viewport': null,
      'photos': null,
      'priceLevel': null,
      'regularOpeningHours': {
        'periods': [
          {
            'close': {'day': 1, 'hour': 2, 'minute': 3},
          },
        ],
      },
    }, photoIdFor: (i) => 'x');
    expect(nulls.location, isNull);
    expect(nulls.regularOpeningHours!.weekdayDescriptions, isEmpty);
    expect(nulls.regularOpeningHours!.periods.single.open, isNull);
    expect(nulls.regularOpeningHours!.periods.single.close!.minute, 3);
  });
  test('webError maps messages', () {
    expect(
      webError('InvalidKeyMapError').code,
      PlaceAutocompleteErrorCode.invalidApiKey,
    );
    expect(
      webError('OVER_QUERY_LIMIT').code,
      PlaceAutocompleteErrorCode.quotaExceeded,
    );
    expect(webError('NOT_FOUND').code, PlaceAutocompleteErrorCode.notFound);
    expect(
      webError('INVALID_REQUEST').code,
      PlaceAutocompleteErrorCode.invalidRequest,
    );
    expect(
      webError('Failed to fetch').code,
      PlaceAutocompleteErrorCode.networkError,
    );
    expect(webError('???').code, PlaceAutocompleteErrorCode.unknown);
    expect(webError('???').message, '???');
  });

  group('final review fixes', () {
    test('webFieldName maps every PlaceField to the Maps JS Place name', () {
      const expected = {
        PlaceField.id: 'id',
        PlaceField.displayName: 'displayName',
        PlaceField.formattedAddress: 'formattedAddress',
        PlaceField.shortFormattedAddress: 'shortFormattedAddress',
        PlaceField.location: 'location',
        PlaceField.viewport: 'viewport',
        PlaceField.addressComponents: 'addressComponents',
        PlaceField.types: 'types',
        PlaceField.primaryType: 'primaryType',
        PlaceField.primaryTypeDisplayName: 'primaryTypeDisplayName',
        PlaceField.rating: 'rating',
        PlaceField.userRatingCount: 'userRatingCount',
        PlaceField.priceLevel: 'priceLevel',
        PlaceField.nationalPhoneNumber: 'nationalPhoneNumber',
        PlaceField.internationalPhoneNumber: 'internationalPhoneNumber',
        PlaceField.websiteUri: 'websiteURI',
        PlaceField.googleMapsUri: 'googleMapsURI',
        PlaceField.utcOffsetMinutes: 'utcOffsetMinutes',
        PlaceField.businessStatus: 'businessStatus',
        PlaceField.editorialSummary: 'editorialSummary',
        PlaceField.regularOpeningHours: 'regularOpeningHours',
        PlaceField.photos: 'photos',
        PlaceField.reviews: 'reviews',
      };
      expect(PlaceField.values, hasLength(23));
      for (final f in PlaceField.values) {
        expect(webFieldName(f), expected[f], reason: f.name);
      }
      // the two URI fields are the only ones that differ from apiName
      expect(
        [
          for (final f in PlaceField.values)
            if (webFieldName(f) != f.apiName) f,
        ],
        [PlaceField.websiteUri, PlaceField.googleMapsUri],
      );
    });

    test('wrong-typed numbers are ignored instead of throwing', () {
      final place = placeFromWebJson({
        'rating': '4.5',
        'userRatingCount': 'many',
        'utcOffsetMinutes': true,
        'location': {'lat': '1', 'lng': 2},
        'reviews': [
          {'rating': 'five'},
        ],
      }, photoIdFor: (i) => 'x');
      expect(place.rating, isNull);
      expect(place.userRatingCount, isNull);
      expect(place.utcOffsetMinutes, isNull);
      expect(place.location, isNull);
      expect(place.reviews!.single.rating, isNull);
      final p = predictionFromWeb({
        'placeId': 'p',
        'distanceMeters': '7',
        'matches': [
          {'startOffset': '0', 'endOffset': 1},
        ],
      });
      expect(p.distanceMeters, isNull);
      expect(p.matchedRanges, isEmpty);
    });

    test('review publishTime accepts a DateTime', () {
      final place = placeFromWebJson({
        'reviews': [
          {'publishTime': DateTime.utc(2024, 1, 2, 3, 4, 5)},
        ],
      }, photoIdFor: (i) => 'x');
      expect(place.reviews!.single.publishTime, '2024-01-02T03:04:05.000Z');
    });

    test('webError maps Places (New) status strings', () {
      for (final m in [
        'PERMISSION_DENIED: API key not valid',
        'UNAUTHENTICATED',
        'ApiNotActivatedMapError',
        'API_KEY_INVALID',
        'RefererNotAllowedMapError',
      ]) {
        expect(
          webError(m).code,
          PlaceAutocompleteErrorCode.invalidApiKey,
          reason: m,
        );
      }
      expect(
        webError('RESOURCE_EXHAUSTED').code,
        PlaceAutocompleteErrorCode.quotaExceeded,
      );
      expect(
        webError('INVALID_ARGUMENT: bad field').code,
        PlaceAutocompleteErrorCode.invalidRequest,
      );
      expect(
        webError('NOT_FOUND: no such place').code,
        PlaceAutocompleteErrorCode.notFound,
      );
    });
  });
}
