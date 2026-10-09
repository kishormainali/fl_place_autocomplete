# fl_place_autocomplete

Google Places autocomplete for Flutter on **Android, iOS and web**, built on
the **Places API (New)** on every platform, with session tokens handled for
you.

- A headless Dart API: `findPredictions`, `fetchPlace` (full field catalog),
  `fetchPhoto`.
- `PlaceAutocompleteField`, a pure-Dart, fully customizable autocomplete text
  field that can return the full `Place` on selection.
- API key via `--dart-define` (per-platform overrides supported), with the
  usual native configuration (manifest / Info.plist / `index.html`) as a
  fallback.

Source and issues: <https://github.com/kishormainali/fl_place_autocomplete>
(links in the package READMEs and pubspecs point at the `main` branch).

This repository is a [federated plugin](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins)
managed as a pub workspace:

| Package | Description |
|---------|-------------|
| [`fl_place_autocomplete`](fl_place_autocomplete) | App-facing package: headless API and widget. **Depend on this one.** |
| [`fl_place_autocomplete_platform_interface`](fl_place_autocomplete_platform_interface) | Models, `PlaceSession`, exceptions and the platform base class. |
| [`fl_place_autocomplete_android`](fl_place_autocomplete_android) | Android: Places SDK for Android (New). |
| [`fl_place_autocomplete_ios`](fl_place_autocomplete_ios) | iOS: Places SDK for iOS (`GooglePlaces` 11.x), **Swift Package Manager only**. |
| [`fl_place_autocomplete_web`](fl_place_autocomplete_web) | Web: Maps JavaScript API, Places library. |

## Quick start

```yaml
dependencies:
  fl_place_autocomplete: ^0.1.0
```

Pass your API key at build time (details in [docs/setup.md](docs/setup.md)):

```sh
flutter run --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY
# or per platform, from a gitignored file:
flutter run --dart-define-from-file=env.json   # {"GOOGLE_PLACES_API_KEY_ANDROID": "...", "GOOGLE_PLACES_API_KEY_IOS": "...", "GOOGLE_PLACES_API_KEY_WEB": "..."}
```

Precedence per platform: `GOOGLE_PLACES_API_KEY_ANDROID|_IOS|_WEB`, then
`GOOGLE_PLACES_API_KEY`, then the native configuration as a fallback:

| Platform | Native fallback | Notes |
|----------|-----------------|-------|
| Android | `AndroidManifest.xml` `<meta-data android:name="com.google.android.geo.API_KEY" .../>` | `minSdk` 23 |
| iOS | `Info.plist` `GMSPlacesAPIKey` | iOS 16+, **SwiftPM only**: `flutter config --enable-swift-package-manager` |
| Web | Maps JavaScript API already loaded by `web/index.html` | with a define, the plugin loads the API itself |

Enable **Places API (New)** (plus **Maps JavaScript API** for the web key).
`--dart-define` values are compiled into the app, so restrict each key to its
platform (Android package + SHA-1, iOS bundle id, web HTTP referrers). Requires Flutter 3.47 or newer (the version this plugin is tested with; SwiftPM is enabled by default from 3.44).

```dart
import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';

PlaceAutocompleteField(
  decoration: const InputDecoration(labelText: 'Search a place'),
  options: PredictionOptions(includedRegionCodes: ['fr']),
  onPlaceSelected: (place) => print('${place.displayName} at ${place.location}'),
);
```

Headless:

```dart
final places = FlPlaceAutocomplete.instance;
final session = places.newSession();
final predictions = await places.findPredictions('eiffel', session: session);
final place = await places.fetchPlace(
  predictions.first.placeId,
  session: session, // concludes the session
  fields: {PlaceField.displayName, PlaceField.location},
);
```

See the [app-facing package README](fl_place_autocomplete/README.md) for the
full API and the [example app](fl_place_autocomplete/example).

## Documentation

- [docs/setup.md](docs/setup.md): Google Cloud, key setup and restrictions per
  platform, iOS SwiftPM requirement, platform differences.
- [docs/sessions-and-billing.md](docs/sessions-and-billing.md): session
  lifecycle, failures and abandoned sessions, the web prediction cache, field
  billing tiers, Google's current session rules.

## Attribution

Google requires apps that show Places data without a Google map to display
Google attribution. The widget's default footer shows **"Powered by Google"**
under the suggestions.

You can restyle or replace it with `footerBuilder`. Replacing or removing it is
an opt-out: **meeting Google's attribution requirements is then your
responsibility as the app developer.** Google's current
[Places API policies](https://developers.google.com/maps/documentation/places/web-service/policies)
(checked 2026-10-08) ask for the Google Maps logo, or the text "Google Maps"
where space is limited, so check whether the default text satisfies the policy
for your use and supply a `footerBuilder` if needed. Photos and reviews also
carry `authorAttributions` that must be shown with them.

## Platform limitations

- **Android:** `languageCode` is ignored (the SDK only sets a language at
  initialization; results use the device/app locale).
- **iOS (GooglePlaces 11.x):** `languageCode` is ignored; `regionCode` is
  ignored for place details; `shortFormattedAddress`, `primaryType`,
  `primaryTypeDisplayName` and `nationalPhoneNumber` are always `null`. No
  CocoaPods support.
- **Web:** an in-session `fetchPlace` uses `placePrediction.toPlace()`, which
  takes no language or region, so those are ignored there.

## Verification status

No real API key was available while Milestone 1 was built, so **nothing has
been verified against the live Places API yet.** What is covered:

| Area | Status |
|------|--------|
| Dart API, session lifecycle, controller, widget | Unit and widget tests against a fake platform |
| Pigeon mapping (Dart side) | Unit tests |
| Android | Kotlin unit tests (session store, error mapping, photo store, field/price/business-status mapping); example builds (`flutter build apk`). No live request made. |
| iOS session/error/range/photo core | Swift unit tests (`fl_place_autocomplete_ios/tool/test_core.sh`); example builds for the simulator. No live request made. |
| Web | `flutter test --platform chrome` with a stubbed `google.maps`: hand-written `Place.toJSON()` fixtures plus class-instance `LatLng`/`LatLngBounds`/`Photo`/`Review` objects (prototype getters, `Date` publish times); `fetchFields` names checked against the Maps JS `Place` reference |

Not yet verified live:

- Autocomplete predictions and `fetchPlace` on **Android**, **iOS** and **web**
  (including that a session concludes as a single billed session).
- The real shape of the web `Place.toJSON()` output that the web mapper parses.
- The range of values the Android SDK returns for `priceLevel` (mapped from an
  integer to `free` ... `veryExpensive`).
- `fetchPhoto` on each platform.

To run the opt-in live test with your own key in `example/env.json` (copy
`env.example.json`; the test is skipped by default, so CI needs no key and
incurs no charges):

```sh
cd fl_place_autocomplete/example
flutter test integration_test/live_test.dart --dart-define-from-file=env.json --dart-define=LIVE=true            # Android / iOS
flutter test integration_test/live_test.dart --dart-define-from-file=env.json --dart-define=LIVE=true -d chrome  # web
```

## Development

```sh
dart pub get                      # resolves the whole workspace
tool/analyze.sh
tool/test.sh                      # VM tests in every package
(cd fl_place_autocomplete_web && flutter test --platform chrome)
(cd fl_place_autocomplete_ios && tool/test_core.sh)   # macOS, pure-Swift core
(cd fl_place_autocomplete/example && flutter build apk --debug && \
  cd android && ./gradlew :fl_place_autocomplete_android:testDebugUnitTest)   # Kotlin tests
tool/generate.sh                  # regenerate Pigeon (Dart, Kotlin, Swift)
dart format .
```

CI (`.github/workflows/ci.yml`) runs analyze, format, tests, a Pigeon
up-to-date check, the Chrome tests, the Kotlin and Swift core tests, and Android, iOS
(simulator, SwiftPM) and web builds of the example.

### Publishing

The packages are versioned and published independently. Because each depends
on the ones below it, publish in this order:

1. `fl_place_autocomplete_platform_interface`
2. `fl_place_autocomplete_android`, `fl_place_autocomplete_ios`,
   `fl_place_autocomplete_web`
3. `fl_place_autocomplete`

## License

MIT, see [LICENSE](LICENSE).
