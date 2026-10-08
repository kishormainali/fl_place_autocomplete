import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';

/// Headless Places autocomplete API.
class FlPlaceAutocomplete {
  /// Creates an API; [platform] defaults to the registered implementation.
  FlPlaceAutocomplete({FlPlaceAutocompletePlatform? platform}) : _override = platform;

  /// Shared instance.
  static final FlPlaceAutocomplete instance = FlPlaceAutocomplete();

  final FlPlaceAutocompletePlatform? _override;
  FlPlaceAutocompletePlatform get _p => _override ?? FlPlaceAutocompletePlatform.instance;

  /// Starts a new single-use session.
  PlaceSession newSession() => PlaceSession.create();

  /// Returns predictions for [input]. Blank input returns an empty list.
  Future<List<PlacePrediction>> findPredictions(String input, {PlaceSession? session, PredictionOptions? options}) async {
    session?.ensureActive();
    if (input.trim().isEmpty) return const [];
    return _p.findPredictions(input, sessionId: session?.id, options: options ?? PredictionOptions());
  }

  /// Fetches place details; ends [session] when the call succeeds.
  Future<Place> fetchPlace(String placeId, {PlaceSession? session, required Set<PlaceField> fields, String? languageCode, String? regionCode}) async {
    if (fields.isEmpty) throw ArgumentError.value(fields, 'fields', 'must not be empty');
    session?.ensureActive();
    final place = await _p.fetchPlace(placeId, sessionId: session?.id, fields: fields, languageCode: languageCode, regionCode: regionCode);
    session?.end();
    return place;
  }

  /// Abandons [session], releasing its native token.
  Future<void> cancelSession(PlaceSession session) async {
    if (session.isEnded) return;
    session.end();
    await _p.disposeSession(session.id);
  }

  /// Fetches a photo for a [PlacePhotoRef].
  Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight}) =>
      _p.fetchPhoto(ref, maxWidth: maxWidth, maxHeight: maxHeight);
}
