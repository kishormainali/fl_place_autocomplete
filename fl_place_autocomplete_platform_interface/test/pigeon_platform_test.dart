import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends PlacesHostApi {
  Object? error;
  String? lastSession;
  List<String>? lastFields;
  @override
  Future<List<PredictionMsg>> findPredictions(
    String input,
    String? sessionId,
    OptionsMsg options,
  ) async {
    if (error != null) throw error!;
    lastSession = sessionId;
    return [
      PredictionMsg(
        placeId: 'p',
        fullText: 'f',
        primaryText: 'f',
        secondaryText: '',
        matchedRanges: [],
        types: [],
      ),
    ];
  }

  @override
  Future<PlaceMsg> fetchPlace(
    String placeId,
    String? sessionId,
    List<String> fields,
    String? languageCode,
    String? regionCode,
  ) async {
    lastSession = sessionId;
    lastFields = fields;
    return PlaceMsg(id: placeId);
  }

  @override
  Future<void> disposeSession(String sessionId) async =>
      lastSession = 'disposed:$sessionId';
  @override
  Future<void> initialize() async {}
  @override
  Future<PhotoDataMsg> fetchPhoto(
    PhotoRefMsg ref,
    int? maxWidth,
    int? maxHeight,
  ) async => PhotoDataMsg(uri: 'u');
}

void main() {
  test('passes session id and field api names through', () async {
    final api = _Api();
    final platform = PigeonPlacesPlatform(api: api);
    await platform.findPredictions(
      'pi',
      sessionId: 's1',
      options: PredictionOptions(),
    );
    expect(api.lastSession, 's1');
    final p = await platform.fetchPlace(
      'p',
      sessionId: 's1',
      fields: {PlaceField.location, PlaceField.displayName},
    );
    expect(p.id, 'p');
    expect(api.lastFields!.toSet(), {'location', 'displayName'});
    await platform.disposeSession('s1');
    expect(api.lastSession, 'disposed:s1');
  });

  test('PlatformException becomes PlaceAutocompleteException', () async {
    final api = _Api()
      ..error = PlatformException(code: 'invalidApiKey', message: 'no key');
    expect(
      PigeonPlacesPlatform(api: api)
          .findPredictions('x', options: PredictionOptions()),
      throwsA(
        isA<PlaceAutocompleteException>().having(
          (e) => e.code,
          'code',
          PlaceAutocompleteErrorCode.invalidApiKey,
        ),
      ),
    );
  });
}
