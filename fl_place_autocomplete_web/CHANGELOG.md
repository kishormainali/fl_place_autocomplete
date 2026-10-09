## 0.1.0

* Initial web implementation on the Maps JavaScript API Places library:
  autocomplete suggestions with session tokens (per-session prediction cache
  so `toPlace()` carries the token), place details via `fetchFields`, and
  photo URIs.
* With a `--dart-define` key and no `google.maps` on the page, injects Google's
  dynamic-loader bootstrap once; a page-loaded Maps JavaScript API always wins.
