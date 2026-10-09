## 0.2.0

* `PlaceAutocompleteField.suggestionsMode` (`PlaceSuggestionsMode.overlay`,
  `bottomSheet`, `dialog`): show suggestions in a modal with its own search
  field instead of an anchored overlay.
* `bottomSheetOptions` / `dialogOptions` (`PlaceBottomSheetOptions`,
  `PlaceDialogOptions`) style the modals: color, shape, elevation, barrier,
  size limits, and the search field (`searchDecoration`, `searchFieldBuilder`,
  `searchPadding`, `autofocusSearch`).
* `panelBuilder` replaces the overlay's chrome.
* The default field and the modal search field inherit `InputDecorationTheme`;
  a custom `decoration` is merged over it.
* All modes respect the keyboard. The overlay height is now capped to the room
  left above or below the field.
* **Behaviour change:** an explicit `openDirection` of `up` or `down` is a
  preference and flips to the other side when the keyboard leaves it too small.
  Previously the overlay always opened on the requested side.

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
