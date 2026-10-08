import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

typedef FindCall = ({
  String input,
  String? sessionId,
  PredictionOptions options,
});
typedef FetchCall = ({
  String placeId,
  String? sessionId,
  Set<PlaceField> fields,
});

class FakePlatform extends FlPlaceAutocompletePlatform
    with MockPlatformInterfaceMixin {
  final findCalls = <FindCall>[];
  final fetchCalls = <FetchCall>[];
  final disposed = <String>[];

  Future<List<PlacePrediction>> Function(String input)? onFind;
  Future<Place> Function(String placeId)? onFetch;

  /// When set, [disposeSession] records the id and then throws this.
  Object? disposeError;

  int get totalCalls => findCalls.length + fetchCalls.length + disposed.length;

  @override
  Future<List<PlacePrediction>> findPredictions(
    String input, {
    String? sessionId,
    required PredictionOptions options,
  }) {
    findCalls.add((input: input, sessionId: sessionId, options: options));
    return onFind?.call(input) ?? Future.value([prediction('$input-1')]);
  }

  @override
  Future<Place> fetchPlace(
    String placeId, {
    String? sessionId,
    required Set<PlaceField> fields,
    String? languageCode,
    String? regionCode,
  }) {
    fetchCalls.add((placeId: placeId, sessionId: sessionId, fields: fields));
    return onFetch?.call(placeId) ??
        Future.value(
          Place(
            id: placeId,
            location: const LatLng(1, 2),
            displayName: 'Name $placeId',
          ),
        );
  }

  @override
  Future<void> disposeSession(String sessionId) async {
    disposed.add(sessionId);
    final e = disposeError;
    if (e != null) throw e;
  }
}

PlacePrediction prediction(String id, {String? text}) => PlacePrediction(
  placeId: id,
  fullText: text ?? 'Text $id',
  primaryText: text ?? 'Text $id',
  secondaryText: 'Sub',
  matchedRanges: const [MatchedRange(0, 2)],
  types: const [],
);
