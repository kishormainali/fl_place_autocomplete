/// Platforms that can have their own `--dart-define` API key.
enum PlacesApiPlatform {
  /// `GOOGLE_PLACES_API_KEY_ANDROID`.
  android,

  /// `GOOGLE_PLACES_API_KEY_IOS`.
  ios,

  /// `GOOGLE_PLACES_API_KEY_WEB`.
  web,
}

// `String.fromEnvironment` only reads the compile-time defines in a `const`
// context, so the defines live here as constants and serve as the default
// argument values below; tests pass explicit values instead.
const String _genericKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
const String _androidKey = String.fromEnvironment(
  'GOOGLE_PLACES_API_KEY_ANDROID',
);
const String _iosKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY_IOS');
const String _webKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY_WEB');

String? _nonBlank(String? value) {
  final v = value?.trim();
  return v == null || v.isEmpty ? null : v;
}

/// Resolves the API key passed with `--dart-define` for [platform].
///
/// Returns the platform-specific key (`GOOGLE_PLACES_API_KEY_ANDROID`,
/// `_IOS` or `_WEB`) when non-blank, else the generic
/// `GOOGLE_PLACES_API_KEY` when non-blank, else `null` (the platform then
/// falls back to its native configuration). Values are trimmed.
///
/// The defaults are the compile-time defines; the parameters exist for tests.
String? resolvePlacesApiKey({
  required PlacesApiPlatform platform,
  String generic = _genericKey,
  String? android = _androidKey,
  String? ios = _iosKey,
  String? web = _webKey,
}) {
  final specific = switch (platform) {
    PlacesApiPlatform.android => android,
    PlacesApiPlatform.ios => ios,
    PlacesApiPlatform.web => web,
  };
  return _nonBlank(specific) ?? _nonBlank(generic);
}

/// The generic `GOOGLE_PLACES_API_KEY` define (trimmed), or `null` when
/// blank. Used on targets without a platform-specific define.
String? genericPlacesApiKey({String generic = _genericKey}) =>
    _nonBlank(generic);
