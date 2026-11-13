## 0.3.1

* Every package in the federation now shares one version number, so the
  constraints between them are all `^0.3.1`.
* Builds with Android Gradle Plugin 9.1.1, the floor Flutter 3.50 requires.

## 0.2.0

* **Breaking:** requires Android `minSdk` 24 (was 23).

## 0.1.1

* Requires Flutter 3.47.8 / Dart 3.13.7 or newer. Older SDKs are affected by
  [GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp),
  a TLS man-in-the-middle flaw (compromised eMudhra intermediate CAs) in
  `dart:io` on Android, Windows and Linux. Rebuild and redeploy apps with a
  patched SDK.

## 0.1.0

* Initial Android implementation on the Places SDK for Android (New) 4.4.1:
  autocomplete predictions with session tokens, place details, and photo URIs.
* Uses the `--dart-define` API key sent from Dart, falling back to the
  `com.google.android.geo.API_KEY` manifest meta-data.
