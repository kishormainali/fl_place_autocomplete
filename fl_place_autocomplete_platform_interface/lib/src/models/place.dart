import 'package:meta/meta.dart';

import 'lat_lng.dart';
import 'photo.dart';

/// Price level of a place.
enum PriceLevel {
  /// Free.
  free,

  /// Inexpensive.
  inexpensive,

  /// Moderately priced.
  moderate,

  /// Expensive.
  expensive,

  /// Very expensive.
  veryExpensive,
}

/// Operational status of a business.
enum BusinessStatus {
  /// Operating normally.
  operational,

  /// Temporarily closed.
  closedTemporarily,

  /// Permanently closed.
  closedPermanently,
}

/// A component of a place's address.
@immutable
class AddressComponent {
  /// Creates an address component.
  const AddressComponent({
    this.longText,
    this.shortText,
    this.types = const [],
  });

  /// Full text of the component.
  final String? longText;

  /// Abbreviated text of the component.
  final String? shortText;

  /// Types of the component.
  final List<String> types;
}

/// A day/time within a week; [day] 0 is Sunday.
@immutable
class TimePoint {
  /// Creates a time point.
  const TimePoint({
    required this.day,
    required this.hour,
    required this.minute,
  });

  /// Day of week, 0 = Sunday.
  final int day;

  /// Hour 0-23.
  final int hour;

  /// Minute 0-59.
  final int minute;
}

/// An opening period.
@immutable
class OpeningPeriod {
  /// Creates a period.
  const OpeningPeriod({this.open, this.close});

  /// Opening time.
  final TimePoint? open;

  /// Closing time.
  final TimePoint? close;
}

/// Opening hours of a place.
@immutable
class OpeningHours {
  /// Creates opening hours.
  const OpeningHours({
    this.weekdayDescriptions = const [],
    this.periods = const [],
  });

  /// Human-readable description per weekday.
  final List<String> weekdayDescriptions;

  /// Opening periods.
  final List<OpeningPeriod> periods;
}

/// A user review of a place.
@immutable
class PlaceReview {
  /// Creates a review.
  const PlaceReview({
    this.authorAttribution,
    this.rating,
    this.text,
    this.relativePublishTimeDescription,
    this.publishTime,
  });

  /// Review author.
  final AuthorAttribution? authorAttribution;

  /// Rating given.
  final double? rating;

  /// Review text.
  final String? text;

  /// Relative publish time, e.g. "a month ago".
  final String? relativePublishTimeDescription;

  /// Publish time as an ISO-8601 string.
  final String? publishTime;
}

/// Details of a place; every field is null unless requested and available.
@immutable
class Place {
  /// Creates a place.
  const Place({
    this.id,
    this.displayName,
    this.formattedAddress,
    this.shortFormattedAddress,
    this.location,
    this.viewport,
    this.addressComponents,
    this.types,
    this.primaryType,
    this.primaryTypeDisplayName,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.nationalPhoneNumber,
    this.internationalPhoneNumber,
    this.websiteUri,
    this.googleMapsUri,
    this.utcOffsetMinutes,
    this.businessStatus,
    this.editorialSummary,
    this.regularOpeningHours,
    this.photos,
    this.reviews,
  });

  /// Place ID.
  final String? id;

  /// Display name.
  final String? displayName;

  /// Formatted address.
  final String? formattedAddress;

  /// Short formatted address.
  final String? shortFormattedAddress;

  /// Coordinates.
  final LatLng? location;

  /// Viewport bounds.
  final LatLngBounds? viewport;

  /// Address components.
  final List<AddressComponent>? addressComponents;

  /// Place types.
  final List<String>? types;

  /// Primary type.
  final String? primaryType;

  /// Primary type display name.
  final String? primaryTypeDisplayName;

  /// Average rating.
  final double? rating;

  /// Number of ratings.
  final int? userRatingCount;

  /// Price level.
  final PriceLevel? priceLevel;

  /// National phone number.
  final String? nationalPhoneNumber;

  /// International phone number.
  final String? internationalPhoneNumber;

  /// Website.
  final Uri? websiteUri;

  /// Google Maps URL.
  final Uri? googleMapsUri;

  /// UTC offset in minutes.
  final int? utcOffsetMinutes;

  /// Business status.
  final BusinessStatus? businessStatus;

  /// Editorial summary.
  final String? editorialSummary;

  /// Regular opening hours.
  final OpeningHours? regularOpeningHours;

  /// Photo references.
  final List<PlacePhotoRef>? photos;

  /// Reviews.
  final List<PlaceReview>? reviews;
}
