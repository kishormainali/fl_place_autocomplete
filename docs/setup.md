# Setup

`fl_place_autocomplete` never handles an API key in Dart. Each platform reads
its key from its own native configuration, the same way Google's SDKs expect
it.

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

## 2. Flutter version

Flutter **3.47 or newer** (the version this plugin is tested with; SwiftPM is
enabled by default from 3.44). The packages declare `flutter: ">=3.44.0"`.

## 3. Android

- `minSdk` 23 or higher.
- Add the key to `android/app/src/main/AndroidManifest.xml`, inside
  `<application>`:

  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_API_KEY"/>
  ```

  To keep the key out of source control, use a manifest placeholder
  (`android:value="${GOOGLE_API_KEY}"`) and set
  `manifestPlaceholders["GOOGLE_API_KEY"]` in `android/app/build.gradle.kts`
  from a gitignored `local.properties`, a Gradle property or an environment
  variable. The example app does exactly this.

- The plugin initializes the Places SDK on first use with
  `Places.initializeWithNewPlacesApiEnabled`. If another plugin already
  initialized the SDK, that initialization (and its key) is reused.

## 4. iOS (Swift Package Manager only)

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
- Add the key to `ios/Runner/Info.plist`:

  ```xml
  <key>GMSPlacesAPIKey</key>
  <string>YOUR_API_KEY</string>
  ```

  To keep it out of source control, write `<string>$(GOOGLE_API_KEY)</string>`
  and define `GOOGLE_API_KEY` in a gitignored xcconfig that
  `ios/Flutter/Debug.xcconfig` / `Release.xcconfig` include with
  `#include? "Keys.xcconfig"` (see the example app).
- The plugin calls `GMSPlacesClient.provideAPIKey` on first use. The SDK keeps
  the first key provided in a process, but `GMSPlacesAPIKey` must still be
  present in Info.plist.

## 5. Web

Load the Maps JavaScript API with Google's
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

The plugin calls `google.maps.importLibrary('places')` itself. If the loader is
missing, requests fail with `PlaceAutocompleteErrorCode.invalidApiKey` and a
message saying the Maps JavaScript API was not loaded.

The example app reads the key from a gitignored `web/keys.js`
(`window.GOOGLE_MAPS_API_KEY = "..."`) and only installs the loader when a key
is set.

## 6. Check it works

With the keys in place, run the example app (`fl_place_autocomplete/example`)
or its opt-in live test:

```sh
cd fl_place_autocomplete/example
flutter test integration_test/live_test.dart --dart-define=LIVE=true
```

Errors you may see:

| Error code       | Usual cause                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `invalidApiKey`  | Key missing from the manifest / Info.plist / index.html, key rejected, or the app does not match the key's restrictions |
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
