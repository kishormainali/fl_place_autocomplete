# Setup

The easiest way to give `fl_place_autocomplete` its API key is
`--dart-define` at build time; no native file has to change. The native
configuration Google's SDKs use (AndroidManifest meta-data, Info.plist, a Maps
script in `web/index.html`) keeps working as a fallback.

## 1. Google Cloud

1. Create (or pick) a Google Cloud project with billing enabled.
2. Enable the APIs:
   - **Places API (New)** for Android, iOS and web keys. The legacy "Places
     API" is not used by this plugin and does not need to be enabled.
   - **Maps JavaScript API** as well for the web key (the web implementation
     uses the Places library of the Maps JavaScript API).
3. Create one API key per platform and restrict each one
   ([Google's guide](https://developers.google.com/maps/api-security-best-practices)):

   | Key     | Application restriction                                        | API restriction                              |
   |---------|----------------------------------------------------------------|----------------------------------------------|
   | Android | Android apps: package name + SHA-1 signing certificate fingerprint | Places API (New)                         |
   | iOS     | iOS apps: bundle identifier                                    | Places API (New)                             |
   | Web     | Websites: HTTP referrers (your domains, `localhost` for dev)   | Maps JavaScript API, Places API (New)        |

   Keys shipped in an app binary or web page are visible to users, so the
   application and API restrictions are what protect them. Set quotas and
   budget alerts in the Cloud console as well.

## 2. Pass the key with `--dart-define`

```sh
flutter run --dart-define=GOOGLE_PLACES_API_KEY=YOUR_API_KEY
```

Since keys are usually restricted per platform, each platform can have its own
define, which wins over the generic one:

| Define                           | Used on                     |
|----------------------------------|-----------------------------|
| `GOOGLE_PLACES_API_KEY_ANDROID`  | Android                     |
| `GOOGLE_PLACES_API_KEY_IOS`      | iOS                         |
| `GOOGLE_PLACES_API_KEY_WEB`      | Web                         |
| `GOOGLE_PLACES_API_KEY`          | every platform (fallback)   |

Keep them in a gitignored JSON file and pass it with `--dart-define-from-file`
(the example app ships `env.example.json` as a template):

```json
{
  "GOOGLE_PLACES_API_KEY_ANDROID": "AIza...android",
  "GOOGLE_PLACES_API_KEY_IOS": "AIza...ios",
  "GOOGLE_PLACES_API_KEY_WEB": "AIza...web"
}
```

```sh
flutter run --dart-define-from-file=env.json
flutter build apk --dart-define-from-file=env.json
```

**Precedence**, per platform (first non-blank value wins):

1. `GOOGLE_PLACES_API_KEY_<PLATFORM>` define,
2. `GOOGLE_PLACES_API_KEY` define,
3. native configuration (sections 4-6 below).

No key anywhere: calls fail with `PlaceAutocompleteErrorCode.invalidApiKey` and
a message naming the options.

The plugin reads the defines with `String.fromEnvironment` and sends the key to
the native SDK on the first Places call (Android
`Places.initializeWithNewPlacesApiEnabled`, iOS `GMSPlacesClient.provideAPIKey`);
on web it loads the Maps JavaScript API itself (section 6).

> **`--dart-define` values are not secret.** They are compiled into the app
> binary / JavaScript and can be extracted, exactly like a key in
> AndroidManifest.xml, Info.plist or `index.html`. Protect keys with
> application restrictions: Android package name + SHA-1 certificate
> fingerprint, iOS bundle identifier, web HTTP referrers (section 1).

### CI

Store the keys as CI secrets and write the file (or pass the defines) at build
time, e.g. GitHub Actions:

```yaml
- name: Build release APK
  env:
    PLACES_KEY_ANDROID: ${{ secrets.GOOGLE_PLACES_API_KEY_ANDROID }}
  run: |
    flutter build apk --release \
      --dart-define=GOOGLE_PLACES_API_KEY_ANDROID="$PLACES_KEY_ANDROID"
```

## 3. Flutter version

Flutter **3.47 or newer** (the version this plugin is tested with; SwiftPM is
enabled by default from 3.44). The packages declare `flutter: ">=3.44.0"`.

## 4. Android

- `minSdk` 23 or higher.
- Pass the key with `--dart-define` (section 2), **or** as a native fallback
  add it to `android/app/src/main/AndroidManifest.xml`, inside
  `<application>`:

  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_API_KEY"/>
  ```

  (A gitignored `--dart-define-from-file` JSON keeps the key out of source
  control without touching native files.)

- The plugin initializes the Places SDK on first use with
  `Places.initializeWithNewPlacesApiEnabled`, using the `--dart-define` key and
  otherwise the manifest meta-data. If another plugin already initialized the
  SDK, that initialization (and its key) is reused and no key is needed.

## 5. iOS (Swift Package Manager only)

The iOS implementation depends on Google's
[`ios-places-sdk`](https://github.com/googlemaps/ios-places-sdk) Swift package
(`GooglePlaces` 11.x) and ships **no CocoaPods podspec**.

- Enable Swift Package Manager support in Flutter if it is not already on:

  ```sh
  flutter config --enable-swift-package-manager
  ```

  If SwiftPM is disabled, Flutter cannot find an iOS implementation for
  `fl_place_autocomplete_ios` (there is no podspec to fall back to): the iOS
  build fails or the plugin is missing at runtime. CocoaPods-only projects are
  not supported.
- Set the iOS deployment target to **16.0** or higher (Xcode: *Runner >
  General > Minimum Deployments*, and `IPHONEOS_DEPLOYMENT_TARGET` in the
  project). The Places SDK 11.x requires it.
- Pass the key with `--dart-define` (section 2), **or** as a native fallback
  add it to `ios/Runner/Info.plist`:

  ```xml
  <key>GMSPlacesAPIKey</key>
  <string>YOUR_API_KEY</string>
  ```

  (A gitignored `--dart-define-from-file` JSON keeps the key out of source
  control without touching native files.)
- The plugin calls `GMSPlacesClient.provideAPIKey` on first use with the
  `--dart-define` key, otherwise `GMSPlacesAPIKey`. The SDK keeps the first key
  provided in a process (also one provided by another plugin), but the plugin
  still needs one of the two to be set.

## 6. Web

With a `--dart-define` key (section 2) nothing else is needed: when
`google.maps` is not on the page, the plugin injects Google's dynamic library
import bootstrap loader into `<head>` once, with that key, and then calls
`google.maps.importLibrary('places')`. A Maps JavaScript API already loaded by
the page always wins and is never replaced. Pages with a strict Content
Security Policy must allow the inline loader script and
`https://maps.googleapis.com`, or load the API themselves as below.

As a native fallback (or to control loading yourself), load the Maps
JavaScript API with Google's
[dynamic library import bootstrap loader](https://developers.google.com/maps/documentation/javascript/load-maps-js-api#dynamic-library-import)
in `web/index.html`, inside `<head>`:

```html
<script>
  (g=>{var h,a,k,p="The Google Maps JavaScript API",c="google",l="importLibrary",q="__ib__",m=document,b=window;b=b[c]||(b[c]={});var d=b.maps||(b.maps={}),r=new Set,e=new URLSearchParams,u=()=>h||(h=new Promise(async(f,n)=>{await (a=m.createElement("script"));e.set("libraries",[...r]+"");for(k in g)e.set(k.replace(/[A-Z]/g,t=>"_"+t[0].toLowerCase()),g[k]);e.set("callback",c+".maps."+q);a.src=`https://maps.${c}apis.com/maps/api/js?`+e;d[q]=f;a.onerror=()=>h=n(Error(p+" could not load."));a.nonce=m.querySelector("script[nonce]")?.nonce||"";m.head.append(a)}));d[l]?console.warn(p+" only loads once. Ignoring:",g):d[l]=(f,...n)=>r.add(f)&&u().then(()=>d[l](f,...n))})({
    key: "YOUR_API_KEY",
    v: "weekly",
  });
</script>
```

The plugin calls `google.maps.importLibrary('places')` itself. With neither a
loaded API nor a key, requests fail with
`PlaceAutocompleteErrorCode.invalidApiKey` and a message listing the three
options.

## 7. Check it works

Put your key in `fl_place_autocomplete/example/env.json` (copy
`env.example.json`) and run the example app or its opt-in live test:

```sh
cd fl_place_autocomplete/example
flutter run --dart-define-from-file=env.json
flutter test integration_test/live_test.dart \
  --dart-define-from-file=env.json --dart-define=LIVE=true
```

Errors you may see:

| Error code       | Usual cause                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `invalidApiKey`  | No `--dart-define` key and none in the manifest / Info.plist / index.html, key rejected, or the app does not match the key's restrictions |
| `quotaExceeded`  | Quota or billing limit reached                                              |
| `invalidRequest` | Places API (New) not enabled for the key, or invalid options               |
| `networkError`   | No connectivity                                                             |

## Platform differences

| Option / field                      | Android            | iOS (GooglePlaces 11.x) | Web                      |
|-------------------------------------|--------------------|-------------------------|--------------------------|
| `languageCode` (predictions)        | ignored (device/app locale) | ignored (device/app locale) | honored         |
| `languageCode` (place details)      | ignored            | ignored                 | honored outside a session only (see below) |
| `regionCode` (predictions)          | honored            | honored                 | honored                  |
| `regionCode` (place details)        | honored            | ignored                 | honored outside a session only |
| `shortFormattedAddress`, `primaryType`, `primaryTypeDisplayName`, `nationalPhoneNumber` | returned | always `null` | returned |
| `fetchPhoto` result                 | `PhotoData.uri`    | `PhotoData.bytes` (JPEG) | `PhotoData.uri`         |

On web, an in-session `fetchPlace` builds the place with
`placePrediction.toPlace()` (the only way to carry the session token), which
takes no language or region, so `languageCode` / `regionCode` passed to
`fetchPlace` only apply when the call is made without a session (or falls back
to a bare `Place`, see [sessions-and-billing.md](sessions-and-billing.md)).
