# fl_place_autocomplete — Design Spec

Date: 2026-10-08

## 1. Goal

An open-source **federated Flutter plugin** for Google Places autocomplete using the **new Places API** on every platform:

- Android: Places SDK for Android (New)
- iOS: Places SDK for iOS (New), distributed via **Swift Package Manager only**
- Web: Maps JavaScript API, Places (New) library

It ships a headless Dart API **and** a fully customizable autocomplete text field widget that can return full place details on selection.

### Success criteria
- Same Dart API and behaviour on Android, iOS and web.
- Session tokens follow Google's documented lifecycle on all platforms (see §4).
- `PlaceAutocompleteField` is customizable at the field, row, state and overlay level.
- Setting an initial value never triggers a Places API call (see §5.4).
- No API key handling in Dart; keys are configured natively per platform (see §6).

### Out of scope for Milestone 1
Text search and nearby search (Milestone 2; they reuse the same Pigeon, field and photo plumbing).

## 2. Packages (melos monorepo)

```
fl_place_autocomplete/                         app-facing: API + widget
fl_place_autocomplete_platform_interface/      abstract class, models, PlaceSession
fl_place_autocomplete_android/                 Kotlin, Places SDK (New) >= 3.5
fl_place_autocomplete_ios/                     Swift, GooglePlaces via SPM only
fl_place_autocomplete_web/                     Dart + dart:js_interop
```

- Android and iOS share one Pigeon schema; the web package calls JS directly.
- The app-facing package endorses the three implementations via `default_package`.
- The public API never exposes Pigeon types; Dart maps them to platform-interface models.

## 3. Headless Dart API

```dart
final places = FlPlaceAutocomplete.instance;
final session = places.newSession();

final preds = await places.findPredictions('pizza', session: session,
  options: PredictionOptions(
    locationBias: ..., locationRestriction: ...,   // circle or rectangle (per-platform support verified)
    origin: LatLng(..), includedPrimaryTypes: [...], // max 5
    includedRegionCodes: ['us', 'ca'],               // max 15
    languageCode: 'en', regionCode: 'us', inputOffset: 5));

final place = await places.fetchPlace(preds.first.placeId, session: session,
  fields: {PlaceField.displayName, PlaceField.location});
```

- `fetchPlace` returns lat/lng as `place.location` (`LatLng?`) when `PlaceField.location` is requested; fields not requested are `null`.
- `PlacePrediction`: `placeId`, `fullText`, `primaryText`, `secondaryText`, `matchedRanges`, `types`, `distanceMeters?`.
- `Place`: typed, all fields nullable, covering the full field catalog (id, displayName, formattedAddress, location, viewport, addressComponents, types, primaryType, rating, userRatingCount, priceLevel, openingHours, phoneNumbers, websiteUri, photos, reviews, ...). `PlaceField` enum maps to native field names.
- `fetchPhoto(PhotoRef, maxWidth, maxHeight)` returns bytes/URL.
- `PlaceAutocompleteException` with codes: `invalidApiKey`, `quotaExceeded`, `networkError`, `invalidRequest`, `notFound`, `sessionEnded`, `unknown`, plus the native message.
- Omitting `session` runs the call outside any session (no token sent).

## 4. Session handling

Per Google's documentation: a session begins at the first autocomplete request, every request in it reuses the same token, it ends when `fetchPlace` is called with that token, and a token must never be reused afterwards.

- **Dart owns the lifecycle.** `newSession()` returns an opaque `PlaceSession`; each native side maps session ID to its real token.
- `PlaceSession` is single-use: after `fetchPlace` completes it is ended, and reuse throws `StateError`.
- Abandoned sessions (blur or clear without selection) are disposed via `disposeSession`.
- **Android:** `AutocompleteSessionToken.newInstance()` kept in a map; the same token goes to `FetchPlaceRequest`; entry removed after fetch.
- **iOS:** `GMSAutocompleteSessionToken` in a dictionary, same pattern.
- **Web:** token rides on the prediction object. The web layer caches, per session, `{AutocompleteSessionToken, Map<placeId, PlacePrediction>}`. `fetchPlace` calls `prediction.toPlace()` (carries the token) then `fetchFields`. If the place ID is not cached it falls back to `new Place({id})` with no token and logs a warning (billed outside the session).

## 5. Widget: `PlaceAutocompleteField`

Pure Dart, built on the headless API; manages sessions automatically.

### 5.1 Parameters
- Behaviour: `controller`, `focusNode`, `initialValue`, `initialPlace`, `options`, `fields` (default: `location`, `displayName`, `formattedAddress`), `debounce` (300 ms), `minChars` (2), `fetchDetailsOnSelect` (true), `onPredictionSelected`, `onPlaceSelected(Place)`, `onError`.
- Look and feel: `decoration` and all common `TextField` pass-throughs, `style`, `textInputAction`, `keyboardType`, overlay decoration / max height / elevation / offset, `openDirection` (auto/up/down).
- Builders (all optional): `fieldBuilder`, `predictionBuilder`, `loadingBuilder`, `emptyBuilder`, `errorBuilder`, `separatorBuilder`, `headerBuilder`, `footerBuilder`.
- `fieldBuilder` gives the controller and focus node so the app renders the field itself; `predictionBuilder` customizes rows only.

### 5.2 Behaviour
- Debounced queries; responses from superseded queries are dropped.
- First query creates a session, later queries reuse it; selection calls `fetchPlace` with it, then discards it; the next input starts a new session.
- Blur or clear without selection disposes the session.
- On selection the overlay closes, the field shows the prediction text, then `onPlaceSelected` fires with the full `Place`.
- `PlaceAutocompleteController`: text, `selectedPlace`, loading/error state, `clear()`, `setText()`, `setPlace()`.
- Keyboard (arrows/enter/escape), overlay follows keyboard, semantic labels.

### 5.3 Attribution
Default footer shows "Powered by Google". It is restylable; removal is a documented opt-out because the attribution requirement rests with the app developer.

### 5.4 Initial value rule
- `initialValue`, controller initial text, `setText()` and `setPlace()` only update text. They never trigger a prediction request, a session, or `fetchPlace`.
- Only user edits start the debounce. The widget flags its own programmatic text changes so the listener ignores them.
- Focusing a field with an initial value does not open the overlay; it opens after the first user edit.
- `initialPlace` pre-populates `selectedPlace` without firing `onPlaceSelected`; editing the text afterwards clears `selectedPlace`.

## 6. API key configuration

Native, per platform; no Dart-side key.
- Android: AndroidManifest meta-data; plugin calls `Places.initializeWithNewPlacesApiEnabled(context, key)` on first use.
- iOS: Info.plist; plugin calls `GMSPlacesClient.provideAPIKey` on first use.
- Web: Maps JS script tag in `index.html`; plugin calls `google.maps.importLibrary('places')` and fails with `invalidApiKey` and a clear message if the script is missing.
- Exact manifest/plist key names are verified against Google's docs during planning.

## 7. Native layer

### Pigeon schema (Android + iOS)
```
@HostApi()
abstract class PlacesHostApi {
  @async void initialize();
  String createSession();
  void disposeSession(String id);
  @async List<PredictionMsg> findPredictions(String input, String? sessionId, OptionsMsg options);
  @async PlaceMsg fetchPlace(String placeId, String? sessionId, List<FieldMsg> fields, String? languageCode, String? regionCode);
  @async PhotoMsg fetchPhoto(PhotoRefMsg ref, int? maxWidth, int? maxHeight);
}
```
Errors cross as `FlutterError` with stable codes mapped to `PlaceAutocompleteException` in Dart.

### Android
Dependency `com.google.android.libraries.places:places` (version pinned in planning). Builds `FindAutocompletePredictionsRequest` and `FetchPlaceRequest`.

### iOS (SPM only)
- Layout: `ios/fl_place_autocomplete_ios/Package.swift` and `Sources/fl_place_autocomplete_ios/`; **no podspec**.
- Depends on `https://github.com/googlemaps/ios-places-sdk` (product `GooglePlaces`) and `FlutterFramework`; minimum iOS 16.
- Flutter documents that plugins should support both SPM and CocoaPods; SPM-only breaks apps that have SPM disabled. Mitigation: require Flutter >= 3.44 (SPM on by default), state "SPM required" in the README, and document the failure mode for CocoaPods-only projects.
- Uses `GMSAutocompleteRequest` / `GMSFetchPlaceRequest`; SDK version `from: 11.2.0` (latest 11.x tag, verified via the repository tags); class names confirmed against the 11.x reference during implementation.

### Web
`dart:js_interop` over `AutocompleteSuggestion.fetchAutocompleteSuggestions`, `AutocompleteSessionToken`, and `Place.fetchFields`.

### To verify during planning (not assumed)
Manifest and plist key names; iOS SDK version and request type names; which bias/restriction shapes each platform accepts; session token expiry.

## 8. Testing
- **Platform interface:** model mapping round-trips, `PlaceSession` single-use rules, `PlaceField` mapping.
- **Session lifecycle** (against a recording fake): one session ID reused per interaction; `fetchPlace` ends it and reuse throws; blur/clear disposes it; a new interaction gets a fresh session; stale responses dropped.
- **Widget:** zero platform calls for initial value / `setText` / `setPlace` / focus; debounce and `minChars`; overlay opens only after user edit; builders receive the right arguments; `onPlaceSelected` carries the full `Place`; keyboard navigation.
- **Native:** Kotlin and Swift mapping and session-map tests; the SDK is wrapped in a thin protocol so tests can fake final classes.
- **Web:** `flutter test --platform chrome` with a stubbed `google.maps`, covering the prediction cache and `toPlace()` path.
- **Live check:** opt-in integration test with the developer's own key, skipped by default so CI needs no key and incurs no charges.

## 9. Example app and repo
- Example shows the headless API, the default widget, a heavily customized widget (custom field, highlighted matches, custom empty/error states), and a place-details view.
- Keys come from a gitignored local config with a documented template.
- Melos scripts: `bootstrap`, `analyze`, `test`, `format`. GitHub Actions: analyze/test, Android build, iOS SPM build, web build.
- `flutter_lints`, per-package README and CHANGELOG, MIT license, docs for key setup, billing, session behaviour and attribution.
- Packages are independently publishable.

## 10. Milestones
1. **Milestone 1:** four packages; autocomplete; `fetchPlace` with the full field catalog; photo fetch; widget; tests; example app; CI.
2. **Milestone 2:** text search and nearby search.
