import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/photo.dart';
import 'models/place.dart';
import 'models/place_field.dart';
import 'models/place_prediction.dart';
import 'models/prediction_options.dart';

/// Platform interface for fl_place_autocomplete.
abstract class FlPlaceAutocompletePlatform extends PlatformInterface {
  /// Constructs the platform.
  FlPlaceAutocompletePlatform() : super(token: _token);

  static final Object _token = Object();
  static FlPlaceAutocompletePlatform _instance = _Unimplemented();

  /// Current implementation.
  static FlPlaceAutocompletePlatform get instance => _instance;

  /// Registers an implementation.
  static set instance(FlPlaceAutocompletePlatform value) {
    PlatformInterface.verify(value, _token);
    _instance = value;
  }

  /// Fetches predictions. [sessionId] null means "no session".
  Future<List<PlacePrediction>> findPredictions(
    String input, {
    String? sessionId,
    required PredictionOptions options,
  }) => throw UnimplementedError('findPredictions() has not been implemented.');

  /// Fetches place details; ends the native session [sessionId] on success.
  Future<Place> fetchPlace(
    String placeId, {
    String? sessionId,
    required Set<PlaceField> fields,
    String? languageCode,
    String? regionCode,
  }) => throw UnimplementedError('fetchPlace() has not been implemented.');

  /// Fetches a photo.
  Future<PhotoData> fetchPhoto(
    PlacePhotoRef ref, {
    int? maxWidth,
    int? maxHeight,
  }) => throw UnimplementedError('fetchPhoto() has not been implemented.');

  /// Drops the native token for [sessionId].
  Future<void> disposeSession(String sessionId) =>
      throw UnimplementedError('disposeSession() has not been implemented.');
}

class _Unimplemented extends FlPlaceAutocompletePlatform {}
