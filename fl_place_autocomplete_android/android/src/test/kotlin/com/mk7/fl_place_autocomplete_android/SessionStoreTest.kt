package com.mk7.fl_place_autocomplete_android

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertSame

class SessionStoreTest {
    @Test fun sameIdReturnsSameToken() {
        var n = 0
        val store = SessionStore { "token-${n++}" }
        assertSame(store.getOrCreate("a"), store.getOrCreate("a"))
        assertEquals(1, n)
    }

    @Test fun differentIdsGetDifferentTokens() {
        var n = 0
        val store = SessionStore { "token-${n++}" }
        assertNotEquals(store.getOrCreate("a"), store.getOrCreate("b"))
    }

    @Test fun removeDropsTheToken() {
        var n = 0
        val store = SessionStore { "token-${n++}" }
        val first = store.getOrCreate("a")
        store.remove("a")
        assertNotEquals(first, store.getOrCreate("a"))
    }

    @Test fun nullIdMeansNoToken() {
        val store = SessionStore { "t" }
        assertEquals(null, store.getOrNull(null))
    }

    @Test fun removingUnknownIdIsANoOp() {
        val store = SessionStore { "t" }
        store.remove("missing")
        assertEquals("t", store.getOrNull("a"))
    }
}
