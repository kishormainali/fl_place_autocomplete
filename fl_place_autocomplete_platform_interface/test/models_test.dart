import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PredictionOptions validation', () {
    test('rejects more than 5 primary types', () {
      expect(
        () => PredictionOptions(includedPrimaryTypes: List.filled(6, 'cafe')),
        throwsArgumentError,
      );
    });
    test('rejects more than 15 region codes', () {
      expect(
        () => PredictionOptions(includedRegionCodes: List.filled(16, 'us')),
        throwsArgumentError,
      );
    });
    test('rejects bias and restriction together', () {
      expect(
        () => PredictionOptions(
          locationBias: const CircularArea(
            center: LatLng(1, 1),
            radiusMeters: 100,
          ),
          locationRestriction: const LatLngBounds(
            southwest: LatLng(0, 0),
            northeast: LatLng(1, 1),
          ),
        ),
        throwsArgumentError,
      );
    });
    test('rejects circle radius outside (0, 50000]', () {
      expect(
        () => PredictionOptions(
          locationBias: const CircularArea(
            center: LatLng(1, 1),
            radiusMeters: 0,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => PredictionOptions(
          locationBias: const CircularArea(
            center: LatLng(1, 1),
            radiusMeters: 50001,
          ),
        ),
        throwsArgumentError,
      );
    });
    test('lower-cases region codes and rejects negative offset', () {
      expect(
        PredictionOptions(includedRegionCodes: ['US']).includedRegionCodes,
        ['us'],
      );
      expect(() => PredictionOptions(inputOffset: -1), throwsArgumentError);
    });
  });

  group('PlacePrediction.matchesWithin', () {
    const p = PlacePrediction(
      placeId: 'id',
      fullText: 'Pizza Hut, NY',
      primaryText: 'Pizza Hut',
      secondaryText: 'NY',
      matchedRanges: [
        MatchedRange(0, 5),
        MatchedRange(7, 12),
        MatchedRange(-3, 2),
        MatchedRange(4, 4),
        MatchedRange(20, 30),
      ],
      types: [],
    );
    test('clamps to length and drops empty or invalid ranges', () {
      final r = p.matchesWithin(9);
      expect(r.map((e) => (e.start, e.end)), [(0, 5), (7, 9), (0, 2)]);
    });
    test('handles empty primary text', () {
      expect(p.matchesWithin(0), isEmpty);
    });
    test('offsets are UTF-16 code units (emoji occupies 2)', () {
      const e = PlacePrediction(
        placeId: 'x',
        fullText: '🍕 Pizza',
        primaryText: '🍕 Pizza',
        secondaryText: '',
        matchedRanges: [MatchedRange(3, 8)],
        types: [],
      );
      expect('🍕 Pizza'.substring(3, 8), 'Pizza');
      expect(e.matchesWithin('🍕 Pizza'.length).single.end, 8);
    });
  });
}
