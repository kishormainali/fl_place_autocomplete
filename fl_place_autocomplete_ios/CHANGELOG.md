## 0.2.0

* **Breaking:** requires an iOS deployment target of 17.0 (was 16.0). The
  Places SDK for iOS 11.x declares `.iOS(.v17)`, so a 16.0 target fails Swift
  Package Manager resolution. Set *Runner > General > Minimum Deployments* to
  17.0.

## 0.1.1

* Requires Flutter 3.47.8 / Dart 3.13.7 or newer. Older SDKs are affected by
  [GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp),
  a TLS man-in-the-middle flaw (compromised eMudhra intermediate CAs) in
  `dart:io` on Android, Windows and Linux. Rebuild and redeploy apps with a
  patched SDK.
* Encode fetched photos to JPEG off the main actor.

## 0.1.0

* Initial iOS implementation on the Places SDK for iOS 11.2 (Swift Package
  Manager only): autocomplete suggestions with session tokens, place details,
  and photo bytes.
* Uses the `--dart-define` API key sent from Dart, falling back to
  `GMSPlacesAPIKey` in Info.plist.
