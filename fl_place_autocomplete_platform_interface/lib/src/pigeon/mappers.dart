import 'package:flutter/services.dart';

import '../exceptions.dart';
import '../models/lat_lng.dart';
import '../models/photo.dart';
import '../models/place.dart';
import '../models/place_prediction.dart';
import '../models/prediction_options.dart';
import 'messages.g.dart';

LatLngMsg _ll(LatLng v) => LatLngMsg(latitude: v.latitude, longitude: v.longitude);
LatLngBoundsMsg _bounds(LatLngBounds b) => LatLngBoundsMsg(southwest: _ll(b.southwest), northeast: _ll(b.northeast));
LatLng _fromLl(LatLngMsg m) => LatLng(m.latitude, m.longitude);
LatLngBounds _fromBounds(LatLngBoundsMsg m) => LatLngBounds(southwest: _fromLl(m.southwest), northeast: _fromLl(m.northeast));

/// Converts options to their Pigeon message.
OptionsMsg optionsToMsg(PredictionOptions o) {
  AreaMsg? bias;
  switch (o.locationBias) {
    case CircularArea(:final center, :final radiusMeters):
      bias = AreaMsg(center: _ll(center), radiusMeters: radiusMeters);
    case RectangularArea(:final bounds):
      bias = AreaMsg(bounds: _bounds(bounds));
    case null:
      break;
  }
  return OptionsMsg(
    locationBias: bias,
    locationRestriction: o.locationRestriction == null ? null : _bounds(o.locationRestriction!),
    origin: o.origin == null ? null : _ll(o.origin!),
    includedPrimaryTypes: o.includedPrimaryTypes,
    includedRegionCodes: o.includedRegionCodes,
    languageCode: o.languageCode,
    regionCode: o.regionCode,
    inputOffset: o.inputOffset,
  );
}

/// Converts a prediction message.
PlacePrediction predictionFromMsg(PredictionMsg m) => PlacePrediction(
      placeId: m.placeId,
      fullText: m.fullText,
      primaryText: m.primaryText,
      secondaryText: m.secondaryText,
      matchedRanges: [for (final r in m.matchedRanges) MatchedRange(r.start, r.end)],
      types: m.types,
      distanceMeters: m.distanceMeters,
    );

AuthorAttribution _author(AuthorAttributionMsg m) => AuthorAttribution(displayName: m.displayName, uri: m.uri, photoUri: m.photoUri);
TimePoint _tp(TimePointMsg m) => TimePoint(day: m.day, hour: m.hour, minute: m.minute);

/// Converts a place message.
Place placeFromMsg(PlaceMsg m) => Place(
      id: m.id,
      displayName: m.displayName,
      formattedAddress: m.formattedAddress,
      shortFormattedAddress: m.shortFormattedAddress,
      location: m.location == null ? null : _fromLl(m.location!),
      viewport: m.viewport == null ? null : _fromBounds(m.viewport!),
      addressComponents: m.addressComponents
          ?.map((c) => AddressComponent(longText: c.longText, shortText: c.shortText, types: c.types))
          .toList(),
      types: m.types,
      primaryType: m.primaryType,
      primaryTypeDisplayName: m.primaryTypeDisplayName,
      rating: m.rating,
      userRatingCount: m.userRatingCount,
      priceLevel: PriceLevel.values.asNameMap()[m.priceLevel],
      nationalPhoneNumber: m.nationalPhoneNumber,
      internationalPhoneNumber: m.internationalPhoneNumber,
      websiteUri: m.websiteUri == null ? null : Uri.tryParse(m.websiteUri!),
      googleMapsUri: m.googleMapsUri == null ? null : Uri.tryParse(m.googleMapsUri!),
      utcOffsetMinutes: m.utcOffsetMinutes,
      businessStatus: BusinessStatus.values.asNameMap()[m.businessStatus],
      editorialSummary: m.editorialSummary,
      regularOpeningHours: m.regularOpeningHours == null
          ? null
          : OpeningHours(
              weekdayDescriptions: m.regularOpeningHours!.weekdayDescriptions,
              periods: [
                for (final p in m.regularOpeningHours!.periods)
                  OpeningPeriod(open: p.open == null ? null : _tp(p.open!), close: p.close == null ? null : _tp(p.close!)),
              ],
            ),
      photos: m.photos
          ?.map((p) => PlacePhotoRef(id: p.id, widthPx: p.widthPx, heightPx: p.heightPx, authorAttributions: p.authorAttributions.map(_author).toList()))
          .toList(),
      reviews: m.reviews
          ?.map((r) => PlaceReview(
                authorAttribution: r.authorAttribution == null ? null : _author(r.authorAttribution!),
                rating: r.rating,
                text: r.text,
                relativePublishTimeDescription: r.relativePublishTimeDescription,
                publishTime: r.publishTime,
              ))
          .toList(),
    );

/// Converts a photo reference to its message.
PhotoRefMsg photoRefToMsg(PlacePhotoRef r) => PhotoRefMsg(
      id: r.id,
      widthPx: r.widthPx,
      heightPx: r.heightPx,
      authorAttributions: [
        for (final a in r.authorAttributions) AuthorAttributionMsg(displayName: a.displayName, uri: a.uri, photoUri: a.photoUri),
      ],
    );

/// Maps a native error to a [PlaceAutocompleteException].
PlaceAutocompleteException mapPlatformException(PlatformException e) => PlaceAutocompleteException(
      code: PlaceAutocompleteErrorCode.values.asNameMap()[e.code] ?? PlaceAutocompleteErrorCode.unknown,
      message: e.message,
    );
