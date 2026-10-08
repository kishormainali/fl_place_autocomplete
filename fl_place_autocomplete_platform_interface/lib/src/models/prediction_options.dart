import 'package:meta/meta.dart';

import 'lat_lng.dart';

/// Options for an autocomplete request.
@immutable
class PredictionOptions {
  /// Creates validated options. Throws [ArgumentError] on invalid input.
  PredictionOptions({
    this.locationBias,
    this.locationRestriction,
    this.origin,
    List<String> includedPrimaryTypes = const [],
    List<String> includedRegionCodes = const [],
    this.languageCode,
    this.regionCode,
    this.inputOffset,
  }) : includedPrimaryTypes = List.unmodifiable(includedPrimaryTypes),
       includedRegionCodes = List.unmodifiable(
         includedRegionCodes.map((c) => c.toLowerCase()),
       ) {
    if (includedPrimaryTypes.length > 5) {
      throw ArgumentError.value(
        includedPrimaryTypes.length,
        'includedPrimaryTypes',
        'at most 5 types are allowed',
      );
    }
    if (includedRegionCodes.length > 15) {
      throw ArgumentError.value(
        includedRegionCodes.length,
        'includedRegionCodes',
        'at most 15 region codes are allowed',
      );
    }
    if (locationBias != null && locationRestriction != null) {
      throw ArgumentError(
        'locationBias and locationRestriction are mutually exclusive',
      );
    }
    final bias = locationBias;
    if (bias is CircularArea &&
        !(bias.radiusMeters > 0 && bias.radiusMeters <= 50000)) {
      throw ArgumentError.value(
        bias.radiusMeters,
        'locationBias.radiusMeters',
        'must be in (0, 50000]',
      );
    }
    if (inputOffset != null && inputOffset! < 0) {
      throw ArgumentError.value(inputOffset, 'inputOffset', 'must be >= 0');
    }
  }

  /// Soft preference for results near an area.
  final PlaceArea? locationBias;

  /// Hard restriction to a rectangle.
  final LatLngBounds? locationRestriction;

  /// Point used to compute `distanceMeters`.
  final LatLng? origin;

  /// Primary place types to include (max 5).
  final List<String> includedPrimaryTypes;

  /// Lower-case two-letter region codes (max 15).
  final List<String> includedRegionCodes;

  /// BCP-47 language code for results.
  final String? languageCode;

  /// Region code for formatting.
  final String? regionCode;

  /// Cursor position in the input.
  final int? inputOffset;
}
