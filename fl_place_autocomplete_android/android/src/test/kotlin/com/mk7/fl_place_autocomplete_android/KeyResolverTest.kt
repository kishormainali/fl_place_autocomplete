package com.mk7.fl_place_autocomplete_android

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class KeyResolverTest {
    @Test fun explicitKeyWins() {
        assertEquals("dart", KeyResolver.pick("dart", "manifest"))
    }

    @Test fun blankExplicitFallsBackToNativeConfig() {
        for (blank in listOf(null, "", "   ", "\t\n")) {
            assertEquals("manifest", KeyResolver.pick(blank, "manifest"), "explicit=$blank")
        }
    }

    @Test fun nullWhenBothBlank() {
        assertNull(KeyResolver.pick(null, null))
        assertNull(KeyResolver.pick(" ", ""))
    }

    @Test fun valuesAreTrimmed() {
        assertEquals("k", KeyResolver.pick("  k ", null))
        assertEquals("m", KeyResolver.pick(null, " m "))
    }

    @Test fun missingKeyMessageNamesBothOptions() {
        val m = KeyResolver.MISSING_KEY_MESSAGE
        assertTrue(m.contains("--dart-define=GOOGLE_PLACES_API_KEY"), m)
        assertTrue(m.contains("com.google.android.geo.API_KEY"), m)
    }
}
