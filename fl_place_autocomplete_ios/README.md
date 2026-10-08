# fl_place_autocomplete_ios

The iOS implementation of [`fl_place_autocomplete`](../fl_place_autocomplete),
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
- Add your API key (with **Places API (New)** enabled) to
  `ios/Runner/Info.plist`:

```xml
<key>GMSPlacesAPIKey</key>
<string>YOUR_API_KEY</string>
```

If the key is missing, calls fail with `PlaceAutocompleteErrorCode.invalidApiKey`.

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
- If the app already provided a Places API key (for example via another
  plugin), that key is reused.

## Development

The session, error-mapping, range and photo-store logic lives in the pure-Swift
`FlPlaceAutocompleteCore` target. Run its unit tests on macOS from this package
directory with:

```sh
FL_PLACE_AUTOCOMPLETE_CORE_ONLY=1 swift test --package-path ios/fl_place_autocomplete_ios
```

The environment variable drops the Flutter and Places dependencies (which only
exist inside a Flutter iOS build) from the manifest.
