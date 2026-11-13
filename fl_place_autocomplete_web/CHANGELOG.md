## 0.3.1

* Every package in the federation now shares one version number, so the
  constraints between them are all `^0.3.1`.
* No functional change since 0.1.1.

## 0.1.1

* Requires Flutter 3.47.8 / Dart 3.13.7 or newer. Older SDKs are affected by
  [GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp),
  a TLS man-in-the-middle flaw (compromised eMudhra intermediate CAs) in
  `dart:io` on Android, Windows and Linux. Rebuild and redeploy apps with a
  patched SDK.
* Bound the photo handle cache to 200 entries (least recently used).

## 0.1.0

* Initial web implementation on the Maps JavaScript API Places library:
  autocomplete suggestions with session tokens (per-session prediction cache
  so `toPlace()` carries the token), place details via `fetchFields`, and
  photo URIs.
* With a `--dart-define` key and no `google.maps` on the page, injects Google's
  dynamic-loader bootstrap once; a page-loaded Maps JavaScript API always wins.
