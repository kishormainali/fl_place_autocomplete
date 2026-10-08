# fl_place_autocomplete

Google Places autocomplete for Flutter on **Android, iOS and web**, built on
the **Places API (New)** on every platform, with session tokens handled for
you.

- A headless Dart API: `findPredictions`, `fetchPlace` (full field catalog),
  `fetchPhoto`.
- `PlaceAutocompleteField`, a pure-Dart, fully customizable autocomplete text
  field that can return the full `Place` on selection.
- No API key in Dart: keys are configured natively per platform.

This repository is a [federated plugin](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins)
managed with [melos](https://melos.invertase.dev) and a pub workspace:

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

Configure an API key per platform (details in [docs/setup.md](docs/setup.md)):

| Platform | Where | Notes |
|----------|-------|-------|
| Android | `AndroidManifest.xml` `<meta-data android:name="com.google.android.geo.API_KEY" .../>` | `minSdk` 23 |
| iOS | `Info.plist` `GMSPlacesAPIKey` | iOS 16+, **SwiftPM only**: `flutter config --enable-swift-package-manager` |
| Web | Maps JavaScript API bootstrap loader in `web/index.html` | |

Enable **Places API (New)** (plus **Maps JavaScript API** for the web key) and
restrict each key to its platform. Flutter >= 3.44 is required.

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
| Android | Kotlin unit tests (session store, error mapping, photo store); example builds (`flutter build apk`). No live request made. |
| iOS session/error/range/photo core | Swift unit tests (`fl_place_autocomplete_ios/tool/test_core.sh`); example builds for the simulator. No live request made. |
| Web | `flutter test --platform chrome` with a stubbed `google.maps` and hand-written `Place.toJSON()` fixtures |

Not yet verified live:

- Autocomplete predictions and `fetchPlace` on **Android**, **iOS** and **web**
  (including that a session concludes as a single billed session).
- The real shape of the web `Place.toJSON()` output that the web mapper parses.
- The range of values the Android SDK returns for `priceLevel` (mapped from an
  integer to `free` ... `veryExpensive`).
- `fetchPhoto` on each platform.

To run the opt-in live test with your own key configured natively (it is
skipped by default, so CI needs no key and incurs no charges):

```sh
cd fl_place_autocomplete/example
flutter test integration_test/live_test.dart --dart-define=LIVE=true            # Android / iOS device or simulator
flutter test integration_test/live_test.dart --dart-define=LIVE=true -d chrome  # web
```

## Development

```sh
dart pub get                      # resolves the whole workspace
dart run melos run analyze
dart run melos run test           # VM tests in every package
(cd fl_place_autocomplete_web && flutter test --platform chrome)
(cd fl_place_autocomplete_ios && tool/test_core.sh)   # macOS, pure-Swift core
(cd fl_place_autocomplete/example && flutter build apk --debug && \
  cd android && ./gradlew :fl_place_autocomplete_android:testDebugUnitTest)   # Kotlin tests
dart run melos run generate       # regenerate Pigeon (Dart, Kotlin, Swift)
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
