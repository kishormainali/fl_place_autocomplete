package com.mk7.fl_place_autocomplete_android

import android.graphics.Typeface
import android.text.Spanned
import android.text.style.CharacterStyle
import android.text.style.StyleSpan
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.libraries.places.api.model.AddressComponent
import com.google.android.libraries.places.api.model.AuthorAttribution
import com.google.android.libraries.places.api.model.AutocompletePrediction
import com.google.android.libraries.places.api.model.CircularBounds
import com.google.android.libraries.places.api.model.DayOfWeek
import com.google.android.libraries.places.api.model.LocationBias
import com.google.android.libraries.places.api.model.OpeningHours
import com.google.android.libraries.places.api.model.PhotoMetadata
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.model.RectangularBounds
import com.google.android.libraries.places.api.model.Review
import com.google.android.libraries.places.api.model.TimeOfWeek
import java.util.UUID

// ---- Request mapping -------------------------------------------------------

fun LatLngMsg.toLatLng(): LatLng = LatLng(latitude, longitude)

fun LatLngBoundsMsg.toRectangle(): RectangularBounds =
    RectangularBounds.newInstance(southwest.toLatLng(), northeast.toLatLng())

/** Circle when [AreaMsg.center] is set, rectangle when [AreaMsg.bounds] is set. */
fun AreaMsg.toBias(): LocationBias? {
    val c = center
    val r = radiusMeters
    if (c != null && r != null) return CircularBounds.newInstance(c.toLatLng(), r)
    return bounds?.toRectangle()
}

/** Maps a Dart `PlaceField.apiName` to the SDK field; unknown names are ignored. */
fun fieldFor(name: String): Place.Field? = when (name) {
    "id" -> Place.Field.ID
    "displayName" -> Place.Field.DISPLAY_NAME
    "formattedAddress" -> Place.Field.FORMATTED_ADDRESS
    "shortFormattedAddress" -> Place.Field.SHORT_FORMATTED_ADDRESS
    "location" -> Place.Field.LOCATION
    "viewport" -> Place.Field.VIEWPORT
    "addressComponents" -> Place.Field.ADDRESS_COMPONENTS
    "types" -> Place.Field.TYPES
    "primaryType" -> Place.Field.PRIMARY_TYPE
    "primaryTypeDisplayName" -> Place.Field.PRIMARY_TYPE_DISPLAY_NAME
    "rating" -> Place.Field.RATING
    "userRatingCount" -> Place.Field.USER_RATING_COUNT
    "priceLevel" -> Place.Field.PRICE_LEVEL
    "nationalPhoneNumber" -> Place.Field.NATIONAL_PHONE_NUMBER
    "internationalPhoneNumber" -> Place.Field.INTERNATIONAL_PHONE_NUMBER
    "websiteUri" -> Place.Field.WEBSITE_URI
    "googleMapsUri" -> Place.Field.GOOGLE_MAPS_URI
    "utcOffsetMinutes" -> Place.Field.UTC_OFFSET
    "businessStatus" -> Place.Field.BUSINESS_STATUS
    "editorialSummary" -> Place.Field.EDITORIAL_SUMMARY
    "regularOpeningHours" -> Place.Field.OPENING_HOURS
    "photos" -> Place.Field.PHOTO_METADATAS
    "reviews" -> Place.Field.REVIEWS
    else -> null
}

// ---- Prediction mapping ----------------------------------------------------

fun AutocompletePrediction.toMsg(): PredictionMsg {
    // The SDK only adds match spans when given a style; null yields plain text.
    val full = getFullText(StyleSpan(Typeface.BOLD))
    return PredictionMsg(
        placeId = placeId,
        fullText = full.toString(),
        primaryText = getPrimaryText(null).toString(),
        secondaryText = getSecondaryText(null).toString(),
        matchedRanges = full.matchedRanges(),
        types = types,
        distanceMeters = distanceMeters?.toLong(),
    )
}

/** Matched ranges are UTF-16 offsets; Android spans already use them. */
fun CharSequence.matchedRanges(): List<MatchedRangeMsg> {
    val spanned = this as? Spanned ?: return emptyList()
    return spanned.getSpans(0, length, CharacterStyle::class.java)
        .map { MatchedRangeMsg(start = spanned.getSpanStart(it).toLong(), end = spanned.getSpanEnd(it).toLong()) }
        .sortedBy { it.start }
}

// ---- Place mapping ---------------------------------------------------------

private fun LatLng.toMsg() = LatLngMsg(latitude = latitude, longitude = longitude)

private fun LatLngBounds.toMsg() = LatLngBoundsMsg(southwest = southwest.toMsg(), northeast = northeast.toMsg())

private fun AddressComponent.toMsg() = AddressComponentMsg(longText = name, shortText = shortName, types = types)

private fun AuthorAttribution.toMsg() = AuthorAttributionMsg(displayName = name, uri = uri, photoUri = photoUri)

private fun DayOfWeek.index(): Long = when (this) {
    DayOfWeek.SUNDAY -> 0
    DayOfWeek.MONDAY -> 1
    DayOfWeek.TUESDAY -> 2
    DayOfWeek.WEDNESDAY -> 3
    DayOfWeek.THURSDAY -> 4
    DayOfWeek.FRIDAY -> 5
    DayOfWeek.SATURDAY -> 6
}

private fun TimeOfWeek.toMsg() = TimePointMsg(day = day.index(), hour = time.hours.toLong(), minute = time.minutes.toLong())

private fun OpeningHours.toMsg() = OpeningHoursMsg(
    weekdayDescriptions = weekdayText,
    periods = periods.map { OpeningPeriodMsg(open = it.open?.toMsg(), close = it.close?.toMsg()) },
)

private fun Review.toMsg() = ReviewMsg(
    authorAttribution = authorAttribution.toMsg(),
    rating = rating,
    text = text,
    relativePublishTimeDescription = relativePublishTimeDescription,
    publishTime = publishTime,
)

private fun PhotoMetadata.toMsg(photos: PhotoStore<PhotoMetadata>) = PhotoRefMsg(
    id = photos.put(this),
    widthPx = width.toLong(),
    heightPx = height.toLong(),
    authorAttributions = authorAttributions?.asList()?.map { it.toMsg() } ?: emptyList(),
)

/** Maps the SDK's 0..4 price level to the Dart `PriceLevel` name. */
internal fun priceLevelName(level: Int?): String? = when (level) {
    0 -> "free"
    1 -> "inexpensive"
    2 -> "moderate"
    3 -> "expensive"
    4 -> "veryExpensive"
    else -> null
}

/**
 * Dart `BusinessStatus` name; null for values added by newer SDKs. The `else`
 * is redundant at compile time but avoids NoWhenBranchMatchedException when a
 * newer SDK at runtime has more constants.
 */
@Suppress("REDUNDANT_ELSE_IN_WHEN")
internal fun Place.BusinessStatus.toName(): String? = when (this) {
    Place.BusinessStatus.OPERATIONAL -> "operational"
    Place.BusinessStatus.CLOSED_TEMPORARILY -> "closedTemporarily"
    Place.BusinessStatus.CLOSED_PERMANENTLY -> "closedPermanently"
    else -> null
}

/** Builds a [PlaceMsg] populating only the fields named in [requested]. */
fun Place.toMsg(requested: Set<String>, photos: PhotoStore<PhotoMetadata>): PlaceMsg {
    fun has(name: String) = name in requested
    return PlaceMsg(
        id = if (has("id")) id else null,
        displayName = if (has("displayName")) displayName else null,
        formattedAddress = if (has("formattedAddress")) formattedAddress else null,
        shortFormattedAddress = if (has("shortFormattedAddress")) shortFormattedAddress else null,
        location = if (has("location")) location?.toMsg() else null,
        viewport = if (has("viewport")) viewport?.toMsg() else null,
        addressComponents = if (has("addressComponents")) addressComponents?.asList()?.map { it.toMsg() } else null,
        types = if (has("types")) placeTypes else null,
        primaryType = if (has("primaryType")) primaryType else null,
        primaryTypeDisplayName = if (has("primaryTypeDisplayName")) primaryTypeDisplayName else null,
        rating = if (has("rating")) rating else null,
        userRatingCount = if (has("userRatingCount")) userRatingCount?.toLong() else null,
        priceLevel = if (has("priceLevel")) priceLevelName(priceLevel) else null,
        nationalPhoneNumber = if (has("nationalPhoneNumber")) nationalPhoneNumber else null,
        internationalPhoneNumber = if (has("internationalPhoneNumber")) internationalPhoneNumber else null,
        websiteUri = if (has("websiteUri")) websiteUri?.toString() else null,
        googleMapsUri = if (has("googleMapsUri")) googleMapsUri?.toString() else null,
        utcOffsetMinutes = if (has("utcOffsetMinutes")) utcOffsetMinutes?.toLong() else null,
        businessStatus = if (has("businessStatus")) businessStatus?.toName() else null,
        editorialSummary = if (has("editorialSummary")) editorialSummary else null,
        regularOpeningHours = if (has("regularOpeningHours")) openingHours?.toMsg() else null,
        photos = if (has("photos")) photoMetadatas?.map { it.toMsg(photos) } else null,
        reviews = if (has("reviews")) reviews?.map { it.toMsg() } else null,
    )
}

// ---- Photo store -----------------------------------------------------------

/**
 * Keeps native photo handles addressable by an opaque id (Dart only sees the id).
 * Least-recently-used entries are evicted beyond [capacity].
 */
class PhotoStore<T : Any>(private val capacity: Int = 200) {
    private val entries = object : LinkedHashMap<String, T>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, T>?): Boolean = size > capacity
    }

    @Synchronized
    fun put(value: T): String = UUID.randomUUID().toString().also { entries[it] = value }

    @Synchronized
    fun get(id: String): T? = entries[id]
}
