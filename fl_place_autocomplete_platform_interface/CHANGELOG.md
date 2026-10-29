## 0.1.1

* Requires Flutter 3.47.8 / Dart 3.13.7 or newer. Older SDKs are affected by
  [GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp),
  a TLS man-in-the-middle flaw (compromised eMudhra intermediate CAs) in
  `dart:io` on Android, Windows and Linux. Rebuild and redeploy apps with a
  patched SDK.
* **Behaviour change:** `PlaceSession.ensureActive` throws a
  `PlaceAutocompleteException` (`sessionEnded`) instead of a `StateError`.

## 0.1.0

* Initial release: models (`PlacePrediction`, `PredictionOptions`, `Place`,
  `PlaceField`, photos, geometry), single-use `PlaceSession`,
  `PlaceAutocompleteException`, `FlPlaceAutocompletePlatform`, and the Pigeon
  schema shared by the Android and iOS implementations.
* `resolvePlacesApiKey` / `PlacesApiPlatform`: `--dart-define` key lookup.
  `PigeonPlacesPlatform` sends the resolved key with the Pigeon
  `initialize(String? apiKey)` call once before the first request (retried
  after a failure).
