## 0.1.0

* Initial release.
* Headless API `FlPlaceAutocomplete`: `newSession`, `findPredictions`,
  `fetchPlace` (full Places API (New) field catalog), `fetchPhoto`,
  `cancelSession`.
* `PlaceAutocompleteField` widget and `PlaceAutocompleteController`:
  debounced queries, stale-response dropping, automatic session handling,
  keyboard navigation, field/row/state/overlay builders, "Powered by Google"
  default footer.
* Endorsed implementations for Android, iOS (Swift Package Manager only) and
  web.
* API key via `--dart-define=GOOGLE_PLACES_API_KEY=...` (per-platform
  `GOOGLE_PLACES_API_KEY_ANDROID` / `_IOS` / `_WEB` win; works with
  `--dart-define-from-file`), with the native configuration (manifest
  meta-data, Info.plist `GMSPlacesAPIKey`, Maps script in `index.html`) as a
  fallback. Define values are compiled into the app: restrict your keys.
