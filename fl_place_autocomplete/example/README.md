# fl_place_autocomplete example

Three tabs:

1. **Headless** – a plain `TextField` + `ListView` driven by
   `FlPlaceAutocomplete.instance` (`newSession` / `findPredictions` /
   `fetchPlace`).
2. **Default field** – `PlaceAutocompleteField` with its default UI and
   `initialValue: 'Eiffel Tower, Paris'` (the initial value never hits the API).
3. **Custom field** – every builder replaced (pill-shaped field with a clear
   button, accent-highlighted rows with distance, empty/error/footer builders),
   all `PlaceField`s requested, results restricted to the US.

## API keys

Keys are configured natively per platform. Only the `*.example` templates are
committed; the real files are gitignored. Without a key the app still builds and
runs, and requests fail with `invalidApiKey`, shown in the UI.

| Platform | File (gitignored)            | Template                          | Consumed as |
|----------|------------------------------|-----------------------------------|-------------|
| Android  | `android/local.properties`   | `android/local.properties.example`| `GOOGLE_API_KEY` → manifest placeholder → `com.google.android.geo.API_KEY` meta-data |
| iOS      | `ios/Flutter/Keys.xcconfig`  | `ios/Flutter/Keys.xcconfig.example`| `GOOGLE_API_KEY` build setting → `GMSPlacesAPIKey` in `Info.plist` |
| Web      | `web/keys.js`                | `web/keys.js.example`             | `window.GOOGLE_MAPS_API_KEY` → Maps JavaScript API bootstrap loader in `web/index.html` |

On Android the key can also come from `-PGOOGLE_API_KEY=...` or a
`GOOGLE_API_KEY` environment variable.

Enable **Places API (New)** for Android/iOS keys, and **Maps JavaScript API** +
**Places API (New)** for the web key. Restrict each key to its platform.

## Running

```bash
flutter run                      # Android / iOS (iOS 16+, Swift Package Manager)
flutter run -d chrome            # Web
flutter test                     # Widget tests with a fake platform
flutter test integration_test/live_test.dart --dart-define=LIVE=true   # needs a key
```
