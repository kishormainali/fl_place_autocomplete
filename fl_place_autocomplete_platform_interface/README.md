# fl_place_autocomplete_platform_interface

A common platform interface for the
[`fl_place_autocomplete`](https://pub.dev/packages/fl_place_autocomplete)
plugin.

This interface allows platform-specific implementations of
`fl_place_autocomplete`, as well as the plugin itself, to ensure they support
the same interface. **Apps should depend on `fl_place_autocomplete`**, which
re-exports the models from this package.

## Contents

- Models: `PlacePrediction`, `PredictionOptions`, `LatLng`, `LatLngBounds`,
  `CircularArea`, `RectangularArea`, `Place` (and its nested types),
  `PlaceField`, `PlacePhotoRef`, `PhotoData`, `AuthorAttribution`.
- `PlaceSession`: the single-use, Dart-owned autocomplete session.
- `PlaceAutocompleteException` and `PlaceAutocompleteErrorCode`.
- `FlPlaceAutocompletePlatform`: the class implementations extend.
- `resolvePlacesApiKey` / `PlacesApiPlatform`: the `--dart-define` API key
  lookup (`GOOGLE_PLACES_API_KEY_ANDROID|_IOS|_WEB`, then
  `GOOGLE_PLACES_API_KEY`).
- The Pigeon schema (`pigeons/messages.dart`) shared by the Android and iOS
  implementations, and `PigeonPlacesPlatform`, the Dart side of it (it sends
  the resolved key to the native side with `initialize(apiKey)` before the
  first call).

## Implementing a new platform

Extend `FlPlaceAutocompletePlatform` and register the instance with
`FlPlaceAutocompletePlatform.instance = MyPlatform();` from your
`registerWith` method. Implement `findPredictions`, `fetchPlace`,
`fetchPhoto` and `disposeSession`:

- Map each `sessionId` to a native session token on first use and reuse it for
  every request with that id.
- On a **successful** `fetchPlace` with a `sessionId`, send the token and then
  drop it. On failure keep it so a retry concludes the same session.
- `disposeSession` drops the token without a details request.
- Throw `PlaceAutocompleteException` with the closest
  `PlaceAutocompleteErrorCode`.

Prefer non-breaking changes (such as adding a method with a default
implementation) over breaking changes to this interface; see
[flutter.dev/go/platform-interface-breaking-changes](https://flutter.dev/go/platform-interface-breaking-changes).
