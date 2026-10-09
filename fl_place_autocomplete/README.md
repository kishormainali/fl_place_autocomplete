# fl_place_autocomplete

Google Places autocomplete for Flutter on **Android, iOS and web**, using the
**Places API (New)** on every platform.

- **Headless API:** `findPredictions`, `fetchPlace` with the full place field
  catalog (location, address components, opening hours, photos, reviews, ...)
  and `fetchPhoto`.
- **`PlaceAutocompleteField`:** a pure-Dart autocomplete text field with
  debouncing, keyboard navigation and builders for the field, rows, loading,
  empty, error, header, separator and footer.
- **Session tokens handled for you**, following Google's session lifecycle.
- **API key via `--dart-define`**, with per-platform overrides and the native
  configuration as a fallback.

| Platform | Backend | Requirements |
|----------|---------|--------------|
| Android | Places SDK for Android (New) | `minSdk` 23 |
| iOS | Places SDK for iOS (`GooglePlaces` 11.x) | iOS 16+, **Swift Package Manager only** |
| Web | Maps JavaScript API, Places library | loaded by the plugin, or by `index.html` |

Requires Flutter 3.47 or newer (the version this plugin is tested with; SwiftPM is enabled by default from 3.44).

## Setup

1. In Google Cloud, enable **Places API (New)** (and **Maps JavaScript API** for
   the web key). Create one key per platform and restrict it.
2. Pass the key at build time:

   ```sh
   flutter run --dart-define=GOOGLE_PLACES_API_KEY=YOUR_API_KEY
   # or keep keys in a gitignored file:
   flutter run --dart-define-from-file=env.json
   ```

   `GOOGLE_PLACES_API_KEY_ANDROID`, `GOOGLE_PLACES_API_KEY_IOS` and
   `GOOGLE_PLACES_API_KEY_WEB` override the generic key on their platform.
   These values are compiled into the app (not secret), so restrict each key:
   Android package name + SHA-1, iOS bundle identifier, web HTTP referrers.
3. Platform requirements: Android `minSdk` 23; iOS 16.0 with SwiftPM enabled
   (`flutter config --enable-swift-package-manager`; CocoaPods is not
   supported).

Without a define, the native configuration is used as a fallback: Android
`com.google.android.geo.API_KEY` manifest meta-data, iOS `GMSPlacesAPIKey` in
Info.plist, web a
[Maps JavaScript API loader](https://developers.google.com/maps/documentation/javascript/load-maps-js-api#dynamic-library-import)
already in `web/index.html`. Precedence: platform define, generic define,
native configuration.

Full instructions, key restrictions and per-platform differences:
[docs/setup.md](https://github.com/kishormainali/fl_place_autocomplete/blob/main/docs/setup.md).

## The widget

```dart
import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';

PlaceAutocompleteField(
  decoration: const InputDecoration(labelText: 'Search a place'),
  options: PredictionOptions(
    includedRegionCodes: ['us', 'ca'],
    locationBias: const CircularArea(
      center: LatLng(40.7128, -74.0060),
      radiusMeters: 20000,
    ),
  ),
  fields: const {
    PlaceField.displayName,
    PlaceField.formattedAddress,
    PlaceField.location,
  },
  onPlaceSelected: (Place place) {
    print('${place.displayName}: ${place.location}');
  },
  onError: (PlaceAutocompleteException e) => print(e.code),
);
```

Behaviour:

- Queries run after `minChars` (2) characters and a `debounce` (300 ms);
  responses to superseded queries are dropped.
- Selecting a prediction closes the list, sets the text, fetches the requested
  `fields` (default: `location`, `displayName`, `formattedAddress`) with the
  same session and calls `onPlaceSelected`.
- `initialValue`, `initialPlace`, focusing the field and programmatic changes
  (`setText`, `setPlace`, `clear`) **never call the API**; only user edits do.
- Arrow keys move the highlight, Enter selects, Escape closes the list.
- Losing focus closes the list and cancels the session. If the field loses
  focus while a selection's details are still loading, a successful fetch is
  still delivered; a failed one is reported through `onError` without
  reopening the list.

### Customization

The default field inherits your app's `InputDecorationTheme`: `decoration` (and
the modal's `searchDecoration`) is merged over it, so you only set what differs.
`decoration: null` opts out of both.

| Parameter | Customizes |
|-----------|------------|
| `decoration`, `style`, `textInputAction`, `keyboardType`, `textCapitalization`, `enabled`, `autofocus` | The default `TextField` |
| `fieldBuilder` | The whole field: you get the `PlaceAutocompleteController`, `FocusNode` and an `onSubmit` callback. The suggestions panel is a `TextFieldTapRegion`, so a `TextField` with the default `groupId` stays focused when a row is tapped; a custom `groupId`/`onTapOutside` must not unfocus on panel taps |
| `predictionBuilder` | A suggestion row (`prediction`, `highlighted`, `onTap`); `DefaultPredictionTile` is the default |
| `loadingBuilder`, `emptyBuilder`, `errorBuilder` (with `retry`) | List states |
| `headerBuilder`, `separatorBuilder`, `footerBuilder` | List chrome |
| `overlayDecoration`, `overlayMaxHeight`, `overlayElevation`, `overlayOffset`, `openDirection` | The suggestions overlay |
| `suggestionsMode` | Where suggestions appear: `PlaceSuggestionsMode.overlay` (default), `.bottomSheet` or `.dialog` |
| `panelBuilder` | The overlay's chrome: `(context, content)` returns your own panel around the header, rows and footer (bound its height; use a `Material` ancestor for the rows) |
| `bottomSheetOptions`, `dialogOptions` | The modal: color, shape, elevation, drag handle, barrier, safe area, max width/height share, plus the modal's search field: `searchDecoration`, `searchFieldBuilder`, `searchPadding`, `autofocusSearch` (`PlaceBottomSheetOptions` / `PlaceDialogOptions`) |

### Suggestion modes

```dart
PlaceAutocompleteField(
  suggestionsMode: PlaceSuggestionsMode.bottomSheet, // or .dialog / .overlay
  decoration: const InputDecoration(labelText: 'Search a place'),
  onPlaceSelected: (place) {},
);
```

In `bottomSheet` and `dialog` mode the inline field becomes a tap target. Tapping
it opens a modal with its own search field, built the same way as the inline one
(`fieldBuilder`, or the default `TextField` with `decoration`) and sharing the
controller's text. The modal field falls back to the inline `decoration` and
`fieldBuilder`, and `searchDecoration` / `searchFieldBuilder` in the options
override them for the modal only. Selecting a row closes the modal; dismissing it without a
selection ends the session and keeps the text. The modal is styled by the app's
`BottomSheetThemeData` / `DialogThemeData`; `overlayDecoration`,
`overlayMaxHeight`, `overlayElevation`, `overlayOffset`, `openDirection` and
`panelBuilder` apply to the overlay only. `header`, `footer`, `predictionBuilder`
and the state builders apply in every mode.

**Keyboard.** All three modes stay clear of the on-screen keyboard. The overlay
opens on the side with more room and its height is capped to that room (an
explicit `openDirection` flips if the keyboard leaves that side too small); the
sheet is lifted by the keyboard inset and the dialog moves with it, both capped
by `maxHeightFactor` and with a scrolling list. A `panelBuilder` panel is yours
to bound.

### Controller

`PlaceAutocompleteController` exposes the text (`textController`),
`selectedPlace`, `status` (`idle`/`loading`/`results`/`empty`/`error`),
`predictions`, `error`, and `setText()`, `setPlace()`, `clear()`, `retry()`.

An external controller may outlive its field. When the field is disposed (or
given a different controller) it calls `controller.detach()`, which cancels any
pending query, drops in-flight results and callbacks, and cancels the session;
the text and `selectedPlace` are kept. Typing into a detached controller does
nothing until it is attached to a field again.

To fetch details yourself, set `fetchDetailsOnSelect: false` and call
`controller.takeSession()` **synchronously inside `onPredictionSelected`**; you
then own the session and must end it with `fetchPlace` or `cancelSession`.

## Headless API

```dart
final places = FlPlaceAutocomplete.instance;
final session = places.newSession();

final predictions = await places.findPredictions(
  'pizza',
  session: session,
  options: PredictionOptions(origin: const LatLng(48.8566, 2.3522)),
);

final place = await places.fetchPlace(
  predictions.first.placeId,
  session: session, // ends the session; reusing it throws StateError
  fields: {PlaceField.displayName, PlaceField.location, PlaceField.photos},
);

final photo = await places.fetchPhoto(place.photos!.first, maxWidth: 400);
// photo.uri on Android and web, photo.bytes on iOS.
```

- A failed `fetchPlace` keeps the session active so you can retry.
- `cancelSession(session)` abandons a session you no longer need.
- Omitting `session` sends no token; each request is billed separately.
- Fields you did not request are `null`.
- Failures throw `PlaceAutocompleteException` with a `code`
  (`invalidApiKey`, `quotaExceeded`, `networkError`, `invalidRequest`,
  `notFound`, `sessionEnded`, `unknown`) and the native `message`. The
  widget reports selecting with a session that was already ended elsewhere as
  `sessionEnded` (Retry then fetches without the session).

How sessions are billed, what happens on failure or abandonment, and the web
caveats:
[docs/sessions-and-billing.md](https://github.com/kishormainali/fl_place_autocomplete/blob/main/docs/sessions-and-billing.md).

## Attribution

The default footer shows **"Powered by Google"**. You can restyle or replace it
with `footerBuilder`, but then meeting Google's attribution requirements is
**your responsibility as the app developer**. Google's current
[Places API policies](https://developers.google.com/maps/documentation/places/web-service/policies)
ask for the Google Maps logo, or the text "Google Maps" where space is limited;
check them for your use. Show the `authorAttributions` of photos and reviews
with them.

## Platform limitations

- **Android:** `languageCode` is ignored (device/app locale is used).
- **iOS:** `languageCode` is ignored; `regionCode` is ignored for place
  details; `shortFormattedAddress`, `primaryType`, `primaryTypeDisplayName` and
  `nationalPhoneNumber` are always `null`.
- **Web:** `languageCode` / `regionCode` passed to an in-session `fetchPlace`
  are ignored (`placePrediction.toPlace()` does not take them).

Milestone 1 has not yet been verified against the live API; see
[Verification status](https://github.com/kishormainali/fl_place_autocomplete#verification-status).

## Example

The [example app](https://github.com/kishormainali/fl_place_autocomplete/tree/main/fl_place_autocomplete/example)
shows the headless API, the default field, a fully customized field, and the
three suggestion modes (with a custom overlay panel).
