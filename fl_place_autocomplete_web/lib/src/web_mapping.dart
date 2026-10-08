import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';

double? _num(Object? v) => (v as num?)?.toDouble();

int? _int(Object? v) => (v as num?)?.toInt();

String? _str(Object? v) => v is String ? v : null;

Map<Object?, Object?>? _map(Object? v) => v is Map ? v : null;

List<String>? _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e != null) e.toString(),
      ]
    : null;

Map<String, Object?> _latLng(LatLng p) => {
  'lat': p.latitude,
  'lng': p.longitude,
};

Map<String, Object?> _bounds(LatLngBounds b) => {
  'south': b.southwest.latitude,
  'west': b.southwest.longitude,
  'north': b.northeast.latitude,
  'east': b.northeast.longitude,
};

LatLng? _toLatLng(Object? v) {
  final m = _map(v);
  if (m == null) return null;
  final lat = _num(m['lat']);
  final lng = _num(m['lng']);
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

LatLngBounds? _toBounds(Object? v) {
  final m = _map(v);
  if (m == null) return null;
  final s = _num(m['south']);
  final w = _num(m['west']);
  final n = _num(m['north']);
  final e = _num(m['east']);
  if (s == null || w == null || n == null || e == null) return null;
  return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
}

String _camel(String upperSnake) {
  final parts = upperSnake.toLowerCase().split('_').where((p) => p.isNotEmpty);
  var first = true;
  final b = StringBuffer();
  for (final p in parts) {
    b.write(first ? p : p[0].toUpperCase() + p.substring(1));
    first = false;
  }
  return b.toString();
}

T? _enum<T extends Enum>(List<T> values, Object? raw, {String prefix = ''}) {
  final s = _str(raw);
  if (s == null) return null;
  var key = s;
  if (prefix.isNotEmpty && key.startsWith(prefix)) {
    key = key.substring(prefix.length);
  }
  final name = _camel(key);
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

Uri? _uri(Object? v) {
  final s = _str(v);
  return s == null ? null : Uri.tryParse(s);
}

/// Builds the JS `fetchAutocompleteSuggestions` request map for [input].
///
/// Null and empty options are omitted.
Map<String, Object?> requestFromOptions(String input, PredictionOptions o) {
  final bias = o.locationBias;
  return {
    'input': input,
    if (bias is CircularArea)
      'locationBias': {
        'center': _latLng(bias.center),
        'radius': bias.radiusMeters,
      },
    if (bias is RectangularArea) 'locationBias': _bounds(bias.bounds),
    if (o.locationRestriction != null)
      'locationRestriction': _bounds(o.locationRestriction!),
    if (o.origin != null) 'origin': _latLng(o.origin!),
    if (o.includedPrimaryTypes.isNotEmpty)
      'includedPrimaryTypes': o.includedPrimaryTypes,
    if (o.includedRegionCodes.isNotEmpty)
      'includedRegionCodes': o.includedRegionCodes,
    if (o.languageCode != null) 'language': o.languageCode,
    if (o.regionCode != null) 'region': o.regionCode,
    if (o.inputOffset != null) 'inputOffset': o.inputOffset,
  };
}

/// Maps a web prediction JSON map to a [PlacePrediction].
///
/// Match offsets are passed through unchanged.
PlacePrediction predictionFromWeb(Map<String, Object?> json) {
  final matches = json['matches'];
  return PlacePrediction(
    placeId: _str(json['placeId']) ?? '',
    fullText: _str(json['text']) ?? '',
    primaryText: _str(json['mainText']) ?? '',
    secondaryText: _str(json['secondaryText']) ?? '',
    matchedRanges: [
      if (matches is List)
        for (final m in matches)
          if (_map(m) case final mm?)
            if (_int(mm['startOffset']) case final s?)
              if (_int(mm['endOffset']) case final e?) MatchedRange(s, e),
    ],
    types: _strings(json['types']) ?? const [],
    distanceMeters: _int(json['distanceMeters']),
  );
}

AuthorAttribution? _author(Object? v) {
  final m = _map(v);
  if (m == null) return null;
  return AuthorAttribution(
    displayName: _str(m['displayName']),
    uri: _str(m['uri']),
    photoUri: _str(m['photoURI']) ?? _str(m['photoUri']),
  );
}

TimePoint? _timePoint(Object? v) {
  final m = _map(v);
  if (m == null) return null;
  return TimePoint(
    day: _int(m['day']) ?? 0,
    hour: _int(m['hour']) ?? 0,
    minute: _int(m['minute']) ?? 0,
  );
}

OpeningHours? _hours(Object? v) {
  final m = _map(v);
  if (m == null) return null;
  final periods = m['periods'];
  return OpeningHours(
    weekdayDescriptions: _strings(m['weekdayDescriptions']) ?? const [],
    periods: [
      if (periods is List)
        for (final p in periods)
          if (_map(p) case final pm?)
            OpeningPeriod(
              open: _timePoint(pm['open']),
              close: _timePoint(pm['close']),
            ),
    ],
  );
}

/// Maps the web `Place.toJSON()` shape to a [Place].
///
/// Fields absent from [json] stay null. Photo ids come from [photoIdFor].
Place placeFromWebJson(
  Map<Object?, Object?> json, {
  required String Function(int index) photoIdFor,
}) {
  final components = json['addressComponents'];
  final photos = json['photos'];
  final reviews = json['reviews'];
  return Place(
    id: _str(json['id']),
    displayName: _str(json['displayName']),
    formattedAddress: _str(json['formattedAddress']),
    shortFormattedAddress: _str(json['shortFormattedAddress']),
    location: _toLatLng(json['location']),
    viewport: _toBounds(json['viewport']),
    addressComponents: components is List
        ? [
            for (final c in components)
              if (_map(c) case final m?)
                AddressComponent(
                  longText: _str(m['longText']),
                  shortText: _str(m['shortText']),
                  types: _strings(m['types']) ?? const [],
                ),
          ]
        : null,
    types: _strings(json['types']),
    primaryType: _str(json['primaryType']),
    primaryTypeDisplayName: _str(json['primaryTypeDisplayName']),
    rating: _num(json['rating']),
    userRatingCount: _int(json['userRatingCount']),
    priceLevel: _enum(
      PriceLevel.values,
      json['priceLevel'],
      prefix: 'PRICE_LEVEL_',
    ),
    nationalPhoneNumber: _str(json['nationalPhoneNumber']),
    internationalPhoneNumber: _str(json['internationalPhoneNumber']),
    websiteUri: _uri(json['websiteURI'] ?? json['websiteUri']),
    googleMapsUri: _uri(json['googleMapsURI'] ?? json['googleMapsUri']),
    utcOffsetMinutes: _int(json['utcOffsetMinutes']),
    businessStatus: _enum(BusinessStatus.values, json['businessStatus']),
    editorialSummary: _str(json['editorialSummary']),
    regularOpeningHours: _hours(json['regularOpeningHours']),
    photos: photos is List
        ? [
            for (var i = 0; i < photos.length; i++)
              if (_map(photos[i]) case final m?)
                PlacePhotoRef(
                  id: photoIdFor(i),
                  widthPx: _int(m['widthPx']),
                  heightPx: _int(m['heightPx']),
                  authorAttributions: [
                    if (m['authorAttributions'] case final List a)
                      for (final x in a) ?_author(x),
                  ],
                ),
          ]
        : null,
    reviews: reviews is List
        ? [
            for (final r in reviews)
              if (_map(r) case final m?)
                PlaceReview(
                  authorAttribution: _author(m['authorAttribution']),
                  rating: _num(m['rating']),
                  text: _str(m['text']),
                  relativePublishTimeDescription: _str(
                    m['relativePublishTimeDescription'],
                  ),
                  publishTime: _str(m['publishTime']),
                ),
          ]
        : null,
  );
}

/// Maps a JS/Dart error to a [PlaceAutocompleteException] using message
/// heuristics.
PlaceAutocompleteException webError(Object error) {
  final message = error.toString();
  final m = message.toLowerCase();
  final code = switch (m) {
    _ when RegExp(r'invalidkey|api key|apikey|referernotallowed').hasMatch(m) =>
      PlaceAutocompleteErrorCode.invalidApiKey,
    _ when RegExp(r'over_query_limit|quota').hasMatch(m) =>
      PlaceAutocompleteErrorCode.quotaExceeded,
    _ when m.contains('not_found') => PlaceAutocompleteErrorCode.notFound,
    _ when RegExp(r'invalid_request|invalidrequest').hasMatch(m) =>
      PlaceAutocompleteErrorCode.invalidRequest,
    _ when RegExp(r'failed to fetch|network').hasMatch(m) =>
      PlaceAutocompleteErrorCode.networkError,
    _ => PlaceAutocompleteErrorCode.unknown,
  };
  return PlaceAutocompleteException(code: code, message: message);
}
