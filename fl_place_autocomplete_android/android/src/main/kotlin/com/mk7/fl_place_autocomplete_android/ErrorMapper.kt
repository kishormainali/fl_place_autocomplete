package com.mk7.fl_place_autocomplete_android

import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.libraries.places.api.net.PlacesStatusCodes

/** Maps Places SDK status codes to `PlaceAutocompleteErrorCode` names on the Dart side. */
object ErrorMapper {
    fun codeFor(statusCode: Int): String = when (statusCode) {
        PlacesStatusCodes.REQUEST_DENIED -> "invalidApiKey" // 9011
        PlacesStatusCodes.OVER_QUERY_LIMIT -> "quotaExceeded" // 9010
        CommonStatusCodes.NETWORK_ERROR, CommonStatusCodes.TIMEOUT -> "networkError" // 7, 15
        PlacesStatusCodes.INVALID_REQUEST -> "invalidRequest" // 9012
        PlacesStatusCodes.NOT_FOUND -> "notFound" // 9013
        else -> "unknown"
    }
}
