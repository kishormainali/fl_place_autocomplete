# fl_place_autocomplete example

Four tabs:

1. **Headless** – a plain `TextField` + `ListView` driven by
   `FlPlaceAutocomplete.instance` (`newSession` / `findPredictions` /
   `fetchPlace`).
2. **Default field** – `PlaceAutocompleteField` with its default UI and
   `initialValue: 'Eiffel Tower, Paris'` (the initial value never hits the API).
3. **Custom field** – every builder replaced (pill-shaped field with a clear
   button, accent-highlighted rows with distance, empty/error/footer builders),
   all `PlaceField`s requested, results restricted to the US.
4. **Modes** – switch `suggestionsMode` between overlay, bottom sheet and
   dialog, and toggle a custom overlay `panelBuilder`.

## API key

The key is passed at build time with `--dart-define`; nothing is configured
natively in this example. Only the template `env.example.json` is committed;
`env.json` is gitignored.

```bash
cp env.example.json env.json      # then put your key in env.json
flutter run --dart-define-from-file=env.json              # Android / iOS
flutter run -d chrome --dart-define-from-file=env.json    # Web
```

`env.json` may also hold per-platform keys, which win over the generic one:

```json
{
  "GOOGLE_PLACES_API_KEY": "",
  "GOOGLE_PLACES_API_KEY_ANDROID": "",
  "GOOGLE_PLACES_API_KEY_IOS": "",
  "GOOGLE_PLACES_API_KEY_WEB": ""
}
```

Without a key the app still builds and runs, shows a banner with the command
above, and requests fail with `invalidApiKey` (shown in the UI).

Enable **Places API (New)** for Android/iOS keys, and **Maps JavaScript API** +
**Places API (New)** for the web key. `--dart-define` values are compiled into
the app, so restrict each key: Android package name + SHA-1, iOS bundle id,
web HTTP referrers.

## Running

```bash
flutter run --dart-define-from-file=env.json           # Android / iOS (iOS 16+, Swift Package Manager)
flutter run -d chrome --dart-define-from-file=env.json # Web
flutter test                                           # Widget tests with a fake platform
flutter test integration_test/live_test.dart \
  --dart-define-from-file=env.json --dart-define=LIVE=true   # needs a key
```
