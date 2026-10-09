import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api_key.dart';
import '../models/photo.dart';
import '../models/place.dart';
import '../models/place_field.dart';
import '../models/place_prediction.dart';
import '../models/prediction_options.dart';
import '../platform.dart';
import 'mappers.dart';
import 'messages.g.dart';

/// Shared implementation used by the Android and iOS packages.
///
/// Before the first `findPredictions`/`fetchPlace`/`fetchPhoto` it sends the
/// API key to the native side once via `initialize`. The key is `apiKey` when
/// given, else the `--dart-define` key for `platform` (see
/// [resolvePlacesApiKey]); `null` lets the native side use its own
/// configuration. A failed initialize is retried by the next call.
class PigeonPlacesPlatform extends FlPlaceAutocompletePlatform {
  /// Creates the platform; [api] is injectable for tests.
  ///
  /// `platform` selects the platform-specific define; when omitted it follows
  /// `defaultTargetPlatform`, and targets other than Android/iOS use only the
  /// generic `GOOGLE_PLACES_API_KEY`.
  PigeonPlacesPlatform({PlacesHostApi? api, this._apiKey, this._platform})
    : _api = api ?? PlacesHostApi();

  final PlacesHostApi _api;
  final String? _apiKey;
  final PlacesApiPlatform? _platform;
  Future<void>? _initialized;

  String? _resolveKey() {
    if (_apiKey != null) return _apiKey;
    final platform =
        _platform ??
        switch (defaultTargetPlatform) {
          TargetPlatform.android => PlacesApiPlatform.android,
          TargetPlatform.iOS => PlacesApiPlatform.ios,
          _ => null,
        };
    return platform == null
        ? genericPlacesApiKey()
        : resolvePlacesApiKey(platform: platform);
  }

  /// Memoized native initialize; concurrent callers share one call and a
  /// failure clears the memo so the next call retries.
  Future<void> _ensureInitialized() =>
      _initialized ??= Future<void>.sync(() => _api.initialize(_resolveKey()))
          .then(
            (_) {},
            onError: (Object e, StackTrace s) {
              _initialized = null;
              Error.throwWithStackTrace(e, s);
            },
          );

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      throw mapPlatformException(e);
    }
  }

  @override
  Future<List<PlacePrediction>> findPredictions(
    String input, {
    String? sessionId,
    required PredictionOptions options,
  }) => _guard(() async {
    await _ensureInitialized();
    return (await _api.findPredictions(
      input,
      sessionId,
      optionsToMsg(options),
    )).map(predictionFromMsg).toList();
  });

  @override
  Future<Place> fetchPlace(
    String placeId, {
    String? sessionId,
    required Set<PlaceField> fields,
    String? languageCode,
    String? regionCode,
  }) => _guard(() async {
    await _ensureInitialized();
    return placeFromMsg(
      await _api.fetchPlace(
        placeId,
        sessionId,
        fields.map((f) => f.apiName).toList(),
        languageCode,
        regionCode,
      ),
    );
  });

  @override
  Future<PhotoData> fetchPhoto(
    PlacePhotoRef ref, {
    int? maxWidth,
    int? maxHeight,
  }) => _guard(() async {
    await _ensureInitialized();
    final m = await _api.fetchPhoto(photoRefToMsg(ref), maxWidth, maxHeight);
    return PhotoData(bytes: m.bytes, uri: m.uri);
  });

  // Never initializes: disposing needs no key and must not trigger SDK setup.
  @override
  Future<void> disposeSession(String sessionId) =>
      _guard(() => _api.disposeSession(sessionId));
}
