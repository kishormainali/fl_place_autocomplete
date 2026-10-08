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
