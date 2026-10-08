import CoreLocation
import FlPlaceAutocompleteCore
import Foundation
import GooglePlaces

// ---- Request mapping -------------------------------------------------------

extension LatLngMsg {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

extension LatLngBoundsMsg {
    func toRectangle() -> any GMSPlaceLocationBias & GMSPlaceLocationRestriction {
        GMSPlaceRectangularLocationOption(northeast.coordinate, southwest.coordinate)
    }
}

extension AreaMsg {
    /// Circle when `center` + `radiusMeters` are set, rectangle when `bounds` is set.
    func toBias() -> (any GMSPlaceLocationBias)? {
        if let center, let radiusMeters {
            return GMSPlaceCircularLocationOption(center.coordinate, radiusMeters)
        }
        return bounds?.toRectangle()
    }
}

/// Maps a Dart `PlaceField.apiName` to the SDK property. Returns `nil` for
/// unknown names and for fields the iOS SDK cannot return
/// (`shortFormattedAddress`, `primaryType`, `primaryTypeDisplayName`,
/// `nationalPhoneNumber`); those stay `null` in the result.
func propertyFor(_ name: String) -> GMSPlaceProperty? {
    switch name {
    case "id": return .placeID
    case "displayName": return .name
    case "formattedAddress": return .formattedAddress
    case "location": return .coordinate
    case "viewport": return .viewport
    case "addressComponents": return .addressComponents
    case "types": return .types
    case "rating": return .rating
    case "userRatingCount": return .userRatingsTotal
    case "priceLevel": return .priceLevel
    case "internationalPhoneNumber": return .phoneNumber
    case "websiteUri": return .website
    case "googleMapsUri": return .googleMapsLinks
    case "utcOffsetMinutes": return .utcOffsetMinutes
    case "businessStatus": return .businessStatus
    case "editorialSummary": return .editorialSummary
    case "regularOpeningHours": return .openingHours
    case "photos": return .photos
    case "reviews": return .reviews
    default: return nil
    }
}

// ---- Prediction mapping ----------------------------------------------------

extension GMSAutocompletePlaceSuggestion {
    func toMsg() -> PredictionMsg {
        let ranges = Ranges.matched(in: attributedFullText, attribute: .gmsAutocompleteMatchAttribute)
        return PredictionMsg(
            placeId: placeID,
            fullText: attributedFullText.string,
            primaryText: attributedPrimaryText.string,
            secondaryText: attributedSecondaryText?.string ?? "",
            matchedRanges: ranges.map { MatchedRangeMsg(start: Int64($0.start), end: Int64($0.end)) },
            types: types,
            distanceMeters: distanceMeters.map { $0.int64Value }
        )
    }
}

// ---- Place mapping ---------------------------------------------------------

private func latLng(_ c: CLLocationCoordinate2D) -> LatLngMsg {
    LatLngMsg(latitude: c.latitude, longitude: c.longitude)
}

private extension GMSAddressComponent {
    func toMsg() -> AddressComponentMsg {
        AddressComponentMsg(longText: name, shortText: shortName, types: types)
    }
}

private extension GMSPlaceAuthorAttribution {
    func toMsg() -> AuthorAttributionMsg {
        AuthorAttributionMsg(displayName: name, uri: uri?.absoluteString, photoUri: photoURI?.absoluteString)
    }
}

private extension GMSEvent {
    /// Day index 0 = Sunday ... 6 = Saturday (`GMSDayOfWeek` is 1-based from Sunday).
    func toMsg() -> TimePointMsg {
        TimePointMsg(day: Int64(day.rawValue) - 1, hour: Int64(time.hour), minute: Int64(time.minute))
    }
}

private extension GMSOpeningHours {
    func toMsg() -> OpeningHoursMsg {
        OpeningHoursMsg(
            weekdayDescriptions: weekdayText ?? [],
            periods: (periods ?? []).map { OpeningPeriodMsg(open: $0.openEvent.toMsg(), close: $0.closeEvent?.toMsg()) }
        )
    }
}

private let isoFormatter = ISO8601DateFormatter()

private extension GMSPlaceReview {
    func toMsg() -> ReviewMsg {
        ReviewMsg(
            authorAttribution: authorAttribution?.toMsg(),
            rating: rating,
            text: text,
            relativePublishTimeDescription: relativePublishDateDescription,
            publishTime: isoFormatter.string(from: publishDate)
        )
    }
}

private extension GMSPlacePhotoMetadata {
    func toMsg(store: PhotoStore<GMSPlacePhotoMetadata>) -> PhotoRefMsg {
        PhotoRefMsg(
            id: store.put(self),
            widthPx: Int64(maxSize.width),
            heightPx: Int64(maxSize.height),
            authorAttributions: (authorAttributions ?? []).map { $0.toMsg() }
        )
    }
}

private func priceLevelName(_ level: GMSPlacesPriceLevel) -> String? {
    switch level {
    case .free: return "free"
    case .cheap: return "inexpensive"
    case .medium: return "moderate"
    case .high: return "expensive"
    case .expensive: return "veryExpensive"
    default: return nil
    }
}

private func businessStatusName(_ status: GMSPlacesBusinessStatus) -> String? {
    switch status {
    case .operational: return "operational"
    case .closedTemporarily: return "closedTemporarily"
    case .closedPermanently: return "closedPermanently"
    default: return nil
    }
}

extension GMSPlace {
    /// Builds a `PlaceMsg` populating only the fields named in `requested`.
    func toMsg(requested: Set<String>, photos store: PhotoStore<GMSPlacePhotoMetadata>) -> PlaceMsg {
        func has(_ name: String) -> Bool { requested.contains(name) }
        var msg = PlaceMsg()
        if has("id") { msg.id = placeID }
        if has("displayName") { msg.displayName = name }
        if has("formattedAddress") { msg.formattedAddress = formattedAddress }
        if has("location"), CLLocationCoordinate2DIsValid(coordinate) { msg.location = latLng(coordinate) }
        if has("viewport"), let v = viewportInfo, v.isValid {
            msg.viewport = LatLngBoundsMsg(southwest: latLng(v.southWest), northeast: latLng(v.northEast))
        }
        if has("addressComponents") { msg.addressComponents = addressComponents?.map { $0.toMsg() } }
        if has("types") { msg.types = types }
        // The SDK reports 0.0 when the place has no rating.
        if has("rating"), rating > 0 { msg.rating = Double(rating) }
        if has("userRatingCount") { msg.userRatingCount = Int64(userRatingsTotal) }
        if has("priceLevel") { msg.priceLevel = priceLevelName(priceLevel) }
        if has("internationalPhoneNumber") { msg.internationalPhoneNumber = phoneNumber }
        if has("websiteUri") { msg.websiteUri = website?.absoluteString }
        if has("googleMapsUri") { msg.googleMapsUri = googleMapsLinks?.placeURL?.absoluteString }
        if has("utcOffsetMinutes") { msg.utcOffsetMinutes = utcOffsetMinutes?.int64Value }
        if has("businessStatus") { msg.businessStatus = businessStatusName(businessStatus) }
        if has("editorialSummary") { msg.editorialSummary = editorialSummary }
        if has("regularOpeningHours") { msg.regularOpeningHours = openingHours?.toMsg() }
        if has("photos") { msg.photos = photos?.map { $0.toMsg(store: store) } }
        if has("reviews") { msg.reviews = reviews?.map { $0.toMsg() } }
        return msg
    }
}
