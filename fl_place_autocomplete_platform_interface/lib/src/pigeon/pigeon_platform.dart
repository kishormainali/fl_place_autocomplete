import 'package:flutter/services.dart';

import '../models/photo.dart';
import '../models/place.dart';
import '../models/place_field.dart';
import '../models/place_prediction.dart';
import '../models/prediction_options.dart';
import '../platform.dart';
import 'mappers.dart';
import 'messages.g.dart';

/// Shared implementation used by the Android and iOS packages.
class PigeonPlacesPlatform extends FlPlaceAutocompletePlatform {
  /// Creates the platform; [api] is injectable for tests.
  PigeonPlacesPlatform({PlacesHostApi? api}) : _api = api ?? PlacesHostApi();

  final PlacesHostApi _api;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      throw mapPlatformException(e);
    }
  }

  @override
  Future<List<PlacePrediction>> findPredictions(String input, {String? sessionId, required PredictionOptions options}) =>
      _guard(() async => (await _api.findPredictions(input, sessionId, optionsToMsg(options))).map(predictionFromMsg).toList());

  @override
  Future<Place> fetchPlace(String placeId, {String? sessionId, required Set<PlaceField> fields, String? languageCode, String? regionCode}) =>
      _guard(() async => placeFromMsg(await _api.fetchPlace(placeId, sessionId, fields.map((f) => f.apiName).toList(), languageCode, regionCode)));

  @override
  Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight}) => _guard(() async {
        final m = await _api.fetchPhoto(photoRefToMsg(ref), maxWidth, maxHeight);
        return PhotoData(bytes: m.bytes, uri: m.uri);
      });

  @override
  Future<void> disposeSession(String sessionId) => _guard(() => _api.disposeSession(sessionId));
}
