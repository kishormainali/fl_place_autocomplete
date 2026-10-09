# fl_place_autocomplete_ios

The iOS implementation of [`fl_place_autocomplete`](https://pub.dev/packages/fl_place_autocomplete),
built on the [Places SDK for iOS](https://developers.google.com/maps/documentation/places/ios-sdk/overview)
(`GooglePlaces` 11.x, Places API (New) endpoints).

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin):
depend on `fl_place_autocomplete` and it is included automatically.

## Setup

- **Swift Package Manager only.** There is no CocoaPods podspec. Enable SwiftPM
  if your Flutter version does not do so by default:
  `flutter config --enable-swift-package-manager`.
- iOS deployment target **16.0** or higher (required by the Places SDK). In
  Xcode, set *Runner > General > Minimum Deployments* to 16.0.
- Pass your API key (with **Places API (New)** enabled) at build time:
  `--dart-define=GOOGLE_PLACES_API_KEY_IOS=...` (or the generic
  `GOOGLE_PLACES_API_KEY`, or `--dart-define-from-file=env.json`). The value is
  compiled into the app, so restrict the key to your bundle identifier.
- Fallback when no define is set: `GMSPlacesAPIKey` in `ios/Runner/Info.plist`:

```xml
<key>GMSPlacesAPIKey</key>
<string>YOUR_API_KEY</string>
```

If neither is set, calls fail with `PlaceAutocompleteErrorCode.invalidApiKey`.

## Platform notes

- **Language:** the Places SDK for iOS has no per-request language. Results use
  the device/app locale, so `languageCode` passed to predictions or place
  details is ignored on iOS.
- **Region code:** honored for predictions; the SDK's place details request has
  no region code, so it is ignored there.
- **Unsupported place fields:** the SDK does not expose `shortFormattedAddress`,
  `primaryType`, `primaryTypeDisplayName` or `nationalPhoneNumber`; they are
  always `null`. `internationalPhoneNumber` maps to the SDK's phone number and
  `googleMapsUri` to `googleMapsLinks.placeURL`.
- **Photos:** `fetchPhoto` returns JPEG bytes (`PhotoData.bytes`), not a URI.
- A key (define or `GMSPlacesAPIKey`) is required even if another plugin has
  already provided a Places API key; without one every call fails with
  `invalidApiKey`. `GMSPlacesClient.provideAPIKey` is process-wide: when a key
  was provided earlier in the process, the SDK keeps that earlier key.

## Development

The session, error-mapping, key-resolution, range and photo-store logic lives in the pure-Swift
`FlPlaceAutocompleteCore` target. Run its unit tests on macOS from this package
directory with `tool/test_core.sh`, which runs:

```sh
FL_PLACE_AUTOCOMPLETE_CORE_ONLY=1 swift test --package-path ios/fl_place_autocomplete_ios
```

The environment variable drops the Flutter and Places dependencies (which only
exist inside a Flutter iOS build) from the manifest.
