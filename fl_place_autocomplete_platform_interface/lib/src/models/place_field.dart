/// Fields that can be requested from `fetchPlace`.
enum PlaceField {
  /// Place ID.
  id,

  /// Display name.
  displayName,

  /// Formatted address.
  formattedAddress,

  /// Short formatted address.
  shortFormattedAddress,

  /// Coordinates.
  location,

  /// Viewport bounds.
  viewport,

  /// Address components.
  addressComponents,

  /// Place types.
  types,

  /// Primary type.
  primaryType,

  /// Primary type display name.
  primaryTypeDisplayName,

  /// Average rating.
  rating,

  /// Number of ratings.
  userRatingCount,

  /// Price level.
  priceLevel,

  /// National phone number.
  nationalPhoneNumber,

  /// International phone number.
  internationalPhoneNumber,

  /// Website.
  websiteUri,

  /// Google Maps URL.
  googleMapsUri,

  /// UTC offset in minutes.
  utcOffsetMinutes,

  /// Business status.
  businessStatus,

  /// Editorial summary.
  editorialSummary,

  /// Regular opening hours.
  regularOpeningHours,

  /// Photo references.
  photos,

  /// Reviews.
  reviews;

  /// Name used by the native SDKs and the JS API (camelCase).
  String get apiName => name;
}
