package com.mk7.fl_place_autocomplete_android

import com.google.android.libraries.places.api.model.Place
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class PlaceMappingTest {
    /** Every Dart `PlaceField.apiName` (23 fields). */
    private val dartFieldNames = listOf(
        "id", "displayName", "formattedAddress", "shortFormattedAddress", "location",
        "viewport", "addressComponents", "types", "primaryType", "primaryTypeDisplayName",
        "rating", "userRatingCount", "priceLevel", "nationalPhoneNumber",
        "internationalPhoneNumber", "websiteUri", "googleMapsUri", "utcOffsetMinutes",
        "businessStatus", "editorialSummary", "regularOpeningHours", "photos", "reviews",
    )

    @Test fun everyDartFieldNameMapsToADistinctSdkField() {
        assertEquals(23, dartFieldNames.size)
        val mapped = dartFieldNames.map { name ->
            requireNotNull(fieldFor(name)) { "no SDK field for $name" }
        }
        assertEquals(23, mapped.toSet().size)
        assertEquals(Place.Field.WEBSITE_URI, fieldFor("websiteUri"))
        assertEquals(Place.Field.UTC_OFFSET, fieldFor("utcOffsetMinutes"))
        assertEquals(Place.Field.OPENING_HOURS, fieldFor("regularOpeningHours"))
        assertEquals(Place.Field.PHOTO_METADATAS, fieldFor("photos"))
    }

    @Test fun unknownFieldNameIsIgnored() {
        assertNull(fieldFor("websiteURI"))
        assertNull(fieldFor(""))
    }

    @Test fun priceLevelMapsZeroToFour() {
        assertEquals("free", priceLevelName(0))
        assertEquals("inexpensive", priceLevelName(1))
        assertEquals("moderate", priceLevelName(2))
        assertEquals("expensive", priceLevelName(3))
        assertEquals("veryExpensive", priceLevelName(4))
        assertNull(priceLevelName(5))
        assertNull(priceLevelName(-1))
        assertNull(priceLevelName(null))
    }

    @Test fun businessStatusMapsKnownValues() {
        assertEquals("operational", Place.BusinessStatus.OPERATIONAL.toName())
        assertEquals("closedTemporarily", Place.BusinessStatus.CLOSED_TEMPORARILY.toName())
        assertEquals("closedPermanently", Place.BusinessStatus.CLOSED_PERMANENTLY.toName())
        // Every value the SDK defines maps to a name or (for future values) null,
        // never throws.
        for (status in Place.BusinessStatus.values()) {
            status.toName()
        }
        val nullable: String? = Place.BusinessStatus.OPERATIONAL.toName()
        assertEquals("operational", nullable)
    }
}
