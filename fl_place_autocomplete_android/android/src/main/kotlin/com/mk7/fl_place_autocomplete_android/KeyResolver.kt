package com.mk7.fl_place_autocomplete_android

/** Chooses the Places API key: the Dart (`--dart-define`) key first, then the manifest. */
internal object KeyResolver {
    /** Error message when neither a Dart key nor the manifest meta-data is set. */
    const val MISSING_KEY_MESSAGE =
        "No Google Places API key. Pass --dart-define=GOOGLE_PLACES_API_KEY=<key> " +
            "(or GOOGLE_PLACES_API_KEY_ANDROID) to flutter run/build, or add a " +
            "<meta-data android:name=\"com.google.android.geo.API_KEY\" android:value=\"<key>\"/> " +
            "entry to the <application> element of AndroidManifest.xml."

    /** Returns the first non-blank of [explicit] and [fallback], trimmed, or null. */
    fun pick(explicit: String?, fallback: String?): String? =
        explicit?.trim()?.takeIf { it.isNotEmpty() }
            ?: fallback?.trim()?.takeIf { it.isNotEmpty() }
}
