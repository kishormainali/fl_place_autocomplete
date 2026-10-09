## 0.1.0

* Initial release: models (`PlacePrediction`, `PredictionOptions`, `Place`,
  `PlaceField`, photos, geometry), single-use `PlaceSession`,
  `PlaceAutocompleteException`, `FlPlaceAutocompletePlatform`, and the Pigeon
  schema shared by the Android and iOS implementations.
* `resolvePlacesApiKey` / `PlacesApiPlatform`: `--dart-define` key lookup.
  `PigeonPlacesPlatform` sends the resolved key with the Pigeon
  `initialize(String? apiKey)` call once before the first request (retried
  after a failure).
