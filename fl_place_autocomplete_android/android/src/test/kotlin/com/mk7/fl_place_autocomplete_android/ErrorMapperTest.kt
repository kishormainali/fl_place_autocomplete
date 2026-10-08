package com.mk7.fl_place_autocomplete_android

import kotlin.test.Test
import kotlin.test.assertEquals

class ErrorMapperTest {
    @Test fun mapsKnownStatusCodes() {
        assertEquals("invalidApiKey", ErrorMapper.codeFor(9011)) // PlacesStatusCodes.REQUEST_DENIED
        assertEquals("quotaExceeded", ErrorMapper.codeFor(9010)) // PlacesStatusCodes.OVER_QUERY_LIMIT
        assertEquals("networkError", ErrorMapper.codeFor(7)) // CommonStatusCodes.NETWORK_ERROR
        assertEquals("networkError", ErrorMapper.codeFor(15)) // CommonStatusCodes.TIMEOUT
        assertEquals("invalidRequest", ErrorMapper.codeFor(9012)) // PlacesStatusCodes.INVALID_REQUEST
        assertEquals("notFound", ErrorMapper.codeFor(9013)) // PlacesStatusCodes.NOT_FOUND
        assertEquals("unknown", ErrorMapper.codeFor(-1))
    }
}
