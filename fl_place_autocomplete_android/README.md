# fl_place_autocomplete_android

The Android implementation of [`fl_place_autocomplete`](https://pub.dev/packages/fl_place_autocomplete),
built on the [Places SDK for Android (New)](https://developers.google.com/maps/documentation/places/android-sdk/overview).

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin):
depend on `fl_place_autocomplete` and it is included automatically.

## Setup

- `minSdk` 23 or higher.
- Pass your API key (with **Places API (New)** enabled) at build time:
  `--dart-define=GOOGLE_PLACES_API_KEY_ANDROID=...` (or the generic
  `GOOGLE_PLACES_API_KEY`, or `--dart-define-from-file=env.json`). The value is
  compiled into the app, so restrict the key to your package name + SHA-1.
- Fallback when no define is set: the manifest meta-data in
  `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

If neither is set, calls fail with `PlaceAutocompleteErrorCode.invalidApiKey`.

## Platform notes

- **Language:** the Places SDK for Android has no per-request language. Results
  use the locale the SDK was initialized with (the device/app locale), so
  `languageCode` passed to predictions or place details is ignored on Android.
- **Photos:** `fetchPhoto` returns a resolved photo URI (`PhotoData.uri`), not bytes.
- If another plugin already initialized the Places SDK in the same app, that
  initialization (and its key) is reused and the key above is not needed.
