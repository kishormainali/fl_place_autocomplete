import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pigeon/messages.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: '../fl_place_autocomplete_android/android/src/main/kotlin/com/mk7/fl_place_autocomplete_android/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.mk7.fl_place_autocomplete_android'),
  swiftOut: '../fl_place_autocomplete_ios/ios/fl_place_autocomplete_ios/Sources/fl_place_autocomplete_ios/Messages.g.swift',
  dartPackageName: 'fl_place_autocomplete_platform_interface',
))
class LatLngMsg {
  LatLngMsg({required this.latitude, required this.longitude});
  double latitude;
  double longitude;
}

class LatLngBoundsMsg {
  LatLngBoundsMsg({required this.southwest, required this.northeast});
  LatLngMsg southwest;
  LatLngMsg northeast;
}

/// Circle when [center] != null, rectangle when [bounds] != null.
class AreaMsg {
  AreaMsg({this.center, this.radiusMeters, this.bounds});
  LatLngMsg? center;
  double? radiusMeters;
  LatLngBoundsMsg? bounds;
}

class OptionsMsg {
  OptionsMsg({
    this.locationBias,
    this.locationRestriction,
    this.origin,
    required this.includedPrimaryTypes,
    required this.includedRegionCodes,
    this.languageCode,
    this.regionCode,
    this.inputOffset,
  });
  AreaMsg? locationBias;
  LatLngBoundsMsg? locationRestriction;
  LatLngMsg? origin;
  List<String> includedPrimaryTypes;
  List<String> includedRegionCodes;
  String? languageCode;
  String? regionCode;
  int? inputOffset;
}

class MatchedRangeMsg {
  MatchedRangeMsg({required this.start, required this.end});
  int start;
  int end;
}

class PredictionMsg {
  PredictionMsg({
    required this.placeId,
    required this.fullText,
    required this.primaryText,
    required this.secondaryText,
    required this.matchedRanges,
    required this.types,
    this.distanceMeters,
  });
  String placeId;
  String fullText;
  String primaryText;
  String secondaryText;
  List<MatchedRangeMsg> matchedRanges;
  List<String> types;
  int? distanceMeters;
}

class AddressComponentMsg {
  AddressComponentMsg({this.longText, this.shortText, required this.types});
  String? longText;
  String? shortText;
  List<String> types;
}

class TimePointMsg {
  TimePointMsg({required this.day, required this.hour, required this.minute});
  int day;
  int hour;
  int minute;
}

class OpeningPeriodMsg {
  OpeningPeriodMsg({this.open, this.close});
  TimePointMsg? open;
  TimePointMsg? close;
}

class OpeningHoursMsg {
  OpeningHoursMsg({required this.weekdayDescriptions, required this.periods});
  List<String> weekdayDescriptions;
  List<OpeningPeriodMsg> periods;
}

class AuthorAttributionMsg {
  AuthorAttributionMsg({this.displayName, this.uri, this.photoUri});
  String? displayName;
  String? uri;
  String? photoUri;
}

class PhotoRefMsg {
  PhotoRefMsg({required this.id, this.widthPx, this.heightPx, required this.authorAttributions});
  String id;
  int? widthPx;
  int? heightPx;
  List<AuthorAttributionMsg> authorAttributions;
}

class ReviewMsg {
  ReviewMsg({this.authorAttribution, this.rating, this.text, this.relativePublishTimeDescription, this.publishTime});
  AuthorAttributionMsg? authorAttribution;
  double? rating;
  String? text;
  String? relativePublishTimeDescription;
  String? publishTime;
}

/// All fields optional; only requested fields are populated.
/// priceLevel: free|inexpensive|moderate|expensive|veryExpensive.
/// businessStatus: operational|closedTemporarily|closedPermanently.
class PlaceMsg {
  PlaceMsg({
    this.id, this.displayName, this.formattedAddress, this.shortFormattedAddress,
    this.location, this.viewport, this.addressComponents, this.types, this.primaryType,
    this.primaryTypeDisplayName, this.rating, this.userRatingCount, this.priceLevel,
    this.nationalPhoneNumber, this.internationalPhoneNumber, this.websiteUri,
    this.googleMapsUri, this.utcOffsetMinutes, this.businessStatus, this.editorialSummary,
    this.regularOpeningHours, this.photos, this.reviews,
  });
  String? id;
  String? displayName;
  String? formattedAddress;
  String? shortFormattedAddress;
  LatLngMsg? location;
  LatLngBoundsMsg? viewport;
  List<AddressComponentMsg>? addressComponents;
  List<String>? types;
  String? primaryType;
  String? primaryTypeDisplayName;
  double? rating;
  int? userRatingCount;
  String? priceLevel;
  String? nationalPhoneNumber;
  String? internationalPhoneNumber;
  String? websiteUri;
  String? googleMapsUri;
  int? utcOffsetMinutes;
  String? businessStatus;
  String? editorialSummary;
  OpeningHoursMsg? regularOpeningHours;
  List<PhotoRefMsg>? photos;
  List<ReviewMsg>? reviews;
}

class PhotoDataMsg {
  PhotoDataMsg({this.bytes, this.uri});
  Uint8List? bytes;
  String? uri;
}

@HostApi()
abstract class PlacesHostApi {
  /// Validates the native key / SDK setup; throws FlutterError(invalidApiKey) if missing.
  @async
  void initialize();

  /// Drops the native session token for [sessionId], if any.
  void disposeSession(String sessionId);

  @async
  List<PredictionMsg> findPredictions(String input, String? sessionId, OptionsMsg options);

  @async
  PlaceMsg fetchPlace(String placeId, String? sessionId, List<String> fields, String? languageCode, String? regionCode);

  @async
  PhotoDataMsg fetchPhoto(PhotoRefMsg ref, int? maxWidth, int? maxHeight);
}
