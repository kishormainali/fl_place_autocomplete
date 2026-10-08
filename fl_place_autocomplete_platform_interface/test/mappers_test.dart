import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/mappers.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('optionsToMsg maps circle bias and lists', () {
    final msg = optionsToMsg(PredictionOptions(
      locationBias: const CircularArea(center: LatLng(1, 2), radiusMeters: 500),
      includedPrimaryTypes: ['cafe'],
      includedRegionCodes: ['us'],
      languageCode: 'en',
      inputOffset: 3,
    ));
    expect(msg.locationBias!.center!.latitude, 1);
    expect(msg.locationBias!.radiusMeters, 500);
    expect(msg.locationBias!.bounds, isNull);
    expect(msg.includedPrimaryTypes, ['cafe']);
    expect(msg.inputOffset, 3);
  });

  test('optionsToMsg maps rectangle bias and restriction', () {
    const b = LatLngBounds(southwest: LatLng(0, 0), northeast: LatLng(2, 2));
    expect(optionsToMsg(PredictionOptions(locationBias: const RectangularArea(b))).locationBias!.bounds!.northeast.latitude, 2);
    expect(optionsToMsg(PredictionOptions(locationRestriction: b)).locationRestriction!.southwest.longitude, 0);
  });

  test('predictionFromMsg maps ranges and distance', () {
    final p = predictionFromMsg(PredictionMsg(
      placeId: 'p', fullText: 'A, B', primaryText: 'A', secondaryText: 'B',
      matchedRanges: [MatchedRangeMsg(start: 0, end: 1)], types: ['x'], distanceMeters: 42));
    expect(p.matchedRanges.single.end, 1);
    expect(p.distanceMeters, 42);
  });

  test('placeFromMsg maps location, enums, uris, nested lists; unrequested stay null', () {
    final place = placeFromMsg(PlaceMsg(
      id: 'p', location: LatLngMsg(latitude: 9, longitude: 8), priceLevel: 'veryExpensive',
      businessStatus: 'closedTemporarily', websiteUri: 'https://x.dev',
      regularOpeningHours: OpeningHoursMsg(weekdayDescriptions: ['Mon'], periods: [
        OpeningPeriodMsg(open: TimePointMsg(day: 1, hour: 9, minute: 0))]),
      photos: [PhotoRefMsg(id: 'ph', authorAttributions: [AuthorAttributionMsg(displayName: 'N')])],
    ));
    expect(place.location, const LatLng(9, 8));
    expect(place.priceLevel, PriceLevel.veryExpensive);
    expect(place.businessStatus, BusinessStatus.closedTemporarily);
    expect(place.websiteUri, Uri.parse('https://x.dev'));
    expect(place.regularOpeningHours!.periods.single.open!.hour, 9);
    expect(place.photos!.single.authorAttributions.single.displayName, 'N');
    expect(place.displayName, isNull);
    expect(place.reviews, isNull);
  });

  test('mapPlatformException maps known codes and falls back to unknown', () {
    expect(mapPlatformException(PlatformException(code: 'quotaExceeded', message: 'm')).code, PlaceAutocompleteErrorCode.quotaExceeded);
    expect(mapPlatformException(PlatformException(code: 'weird')).code, PlaceAutocompleteErrorCode.unknown);
  });
}
