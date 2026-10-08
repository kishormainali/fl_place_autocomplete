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
- **No API key in Dart:** keys are configured natively per platform.

| Platform | Backend | Requirements |
|----------|---------|--------------|
| Android | Places SDK for Android (New) | `minSdk` 23 |
| iOS | Places SDK for iOS (`GooglePlaces` 11.x) | iOS 16+, **Swift Package Manager only** |
| Web | Maps JavaScript API, Places library | Maps JS bootstrap loader in `index.html` |

Flutter >= 3.44 is required.

## Setup

1. In Google Cloud, enable **Places API (New)** (and **Maps JavaScript API** for
   the web key). Create one key per platform and restrict it.
2. Add the key natively:

   **Android**: `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY"/>
   ```

   **iOS**: `ios/Runner/Info.plist`, and enable SwiftPM
   (`flutter config --enable-swift-package-manager`; CocoaPods is not
   supported) with a deployment target of 16.0:

   ```xml
   <key>GMSPlacesAPIKey</key>
   <string>YOUR_API_KEY</string>
   ```

   **Web**: add Google's
   [Maps JavaScript API bootstrap loader](https://developers.google.com/maps/documentation/javascript/load-maps-js-api#dynamic-library-import)
   with your key to `web/index.html`.

Full instructions, key restrictions and per-platform differences:
[docs/setup.md](https://github.com/mk7/fl_place_autocomplete/blob/main/docs/setup.md).

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

### Customization

| Parameter | Customizes |
|-----------|------------|
| `decoration`, `style`, `textInputAction`, `keyboardType`, `textCapitalization`, `enabled`, `autofocus` | The default `TextField` |
| `fieldBuilder` | The whole field: you get the `PlaceAutocompleteController`, `FocusNode` and an `onSubmit` callback |
| `predictionBuilder` | A suggestion row (`prediction`, `highlighted`, `onTap`); `DefaultPredictionTile` is the default |
| `loadingBuilder`, `emptyBuilder`, `errorBuilder` (with `retry`) | List states |
| `headerBuilder`, `separatorBuilder`, `footerBuilder` | List chrome |
| `overlayDecoration`, `overlayMaxHeight`, `overlayElevation`, `overlayOffset`, `openDirection` | The suggestions overlay |

### Controller

`PlaceAutocompleteController` exposes the text (`textController`),
`selectedPlace`, `status` (`idle`/`loading`/`results`/`empty`/`error`),
`predictions`, `error`, and `setText()`, `setPlace()`, `clear()`, `retry()`.

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
  `notFound`, `sessionEnded`, `unknown`) and the native `message`.

How sessions are billed, what happens on failure or abandonment, and the web
caveats:
[docs/sessions-and-billing.md](https://github.com/mk7/fl_place_autocomplete/blob/main/docs/sessions-and-billing.md).

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
[Verification status](https://github.com/mk7/fl_place_autocomplete#verification-status).

## Example

The [example app](https://github.com/mk7/fl_place_autocomplete/tree/main/fl_place_autocomplete/example)
shows the headless API, the default field, and a fully customized field.
