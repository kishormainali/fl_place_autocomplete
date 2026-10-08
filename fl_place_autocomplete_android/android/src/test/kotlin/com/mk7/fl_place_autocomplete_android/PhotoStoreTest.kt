package com.mk7.fl_place_autocomplete_android

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull

class PhotoStoreTest {
    @Test fun putReturnsIdThatResolves() {
        val store = PhotoStore<String>()
        val a = store.put("a")
        val b = store.put("b")
        assertNotEquals(a, b)
        assertEquals("a", store.get(a))
        assertEquals("b", store.get(b))
    }

    @Test fun unknownIdIsNull() {
        assertNull(PhotoStore<String>().get("nope"))
    }

    @Test fun evictsLeastRecentlyUsedBeyondCapacity() {
        val store = PhotoStore<String>(capacity = 2)
        val a = store.put("a")
        val b = store.put("b")
        store.get(a) // touch a so b becomes eldest
        val c = store.put("c")
        assertNull(store.get(b))
        assertEquals("a", store.get(a))
        assertEquals("c", store.get(c))
    }
}
