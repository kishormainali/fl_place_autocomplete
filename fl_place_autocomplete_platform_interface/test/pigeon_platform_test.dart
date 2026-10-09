import 'dart:async';

import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/messages.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends PlacesHostApi {
  Object? error;

  /// Keys passed to [initialize], one entry per call.
  final List<String?> initKeys = [];

  /// Errors thrown by the next [initialize] calls, consumed in order.
  final List<Object> initErrors = [];

  /// When set, [initialize] waits for it.
  Completer<void>? initGate;
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
  Future<void> initialize(String? apiKey) async {
    initKeys.add(apiKey);
    await initGate?.future;
    if (initErrors.isNotEmpty) throw initErrors.removeAt(0);
  }

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

  group('initialize', () {
    final options = PredictionOptions();

    test('runs once, with the injected key, before the first call', () async {
      final api = _Api();
      final platform = PigeonPlacesPlatform(api: api, apiKey: 'k1');
      expect(api.initKeys, isEmpty);
      await platform.findPredictions('a', options: options);
      expect(api.initKeys, ['k1']);
      await platform.findPredictions('b', options: options);
      await platform.fetchPlace('p', fields: {PlaceField.id});
      await platform.fetchPhoto(
        const PlacePhotoRef(id: 'x', authorAttributions: []),
      );
      expect(api.initKeys, ['k1']);
    });

    test('fetchPlace and fetchPhoto also initialize first', () async {
      final a = _Api();
      await PigeonPlacesPlatform(
        api: a,
        apiKey: 'k',
      ).fetchPlace('p', fields: {PlaceField.id});
      expect(a.initKeys, ['k']);
      final b = _Api();
      await PigeonPlacesPlatform(
        api: b,
        apiKey: 'k',
      ).fetchPhoto(const PlacePhotoRef(id: 'x', authorAttributions: []));
      expect(b.initKeys, ['k']);
    });

    test('a failed initialize surfaces as PlaceAutocompleteException and '
        'the next call retries', () async {
      final api = _Api()
        ..initErrors.add(
          PlatformException(code: 'invalidApiKey', message: 'no key'),
        );
      final platform = PigeonPlacesPlatform(api: api, apiKey: 'k');
      await expectLater(
        platform.findPredictions('a', options: options),
        throwsA(
          isA<PlaceAutocompleteException>().having(
            (e) => e.code,
            'code',
            PlaceAutocompleteErrorCode.invalidApiKey,
          ),
        ),
      );
      expect(api.lastSession, isNull, reason: 'no request after failed init');
      final result = await platform.findPredictions(
        'b',
        sessionId: 's',
        options: options,
      );
      expect(result, hasLength(1));
      expect(api.initKeys, ['k', 'k']);
      await platform.findPredictions('c', options: options);
      expect(api.initKeys, hasLength(2));
    });

    test('concurrent first calls share one initialize', () async {
      final api = _Api()..initGate = Completer<void>();
      final platform = PigeonPlacesPlatform(api: api, apiKey: 'k');
      final calls = [
        platform.findPredictions('a', options: options),
        platform.findPredictions('b', options: options),
        platform.fetchPlace('p', fields: {PlaceField.id}),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(api.initKeys, ['k']);
      api.initGate!.complete();
      await Future.wait(calls);
      expect(api.initKeys, ['k']);
    });

    test('concurrent callers all see a shared failure, then retry', () async {
      final api = _Api()
        ..initGate = Completer<void>()
        ..initErrors.add(PlatformException(code: 'invalidApiKey'));
      final platform = PigeonPlacesPlatform(api: api, apiKey: 'k');
      final a = platform.findPredictions('a', options: options);
      final b = platform.findPredictions('b', options: options);
      api.initGate!.complete();
      await expectLater(a, throwsA(isA<PlaceAutocompleteException>()));
      await expectLater(b, throwsA(isA<PlaceAutocompleteException>()));
      expect(api.initKeys, ['k']);
      await platform.findPredictions('c', options: options);
      expect(api.initKeys, ['k', 'k']);
    });

    test('disposeSession never initializes', () async {
      final api = _Api();
      final platform = PigeonPlacesPlatform(api: api, apiKey: 'k');
      await platform.disposeSession('s');
      expect(api.initKeys, isEmpty);
      expect(api.lastSession, 'disposed:s');
    });

    test('without an injected key the platform define is resolved '
        '(null when no define is set)', () async {
      for (final p in [
        PlacesApiPlatform.android,
        PlacesApiPlatform.ios,
        PlacesApiPlatform.web,
      ]) {
        final api = _Api();
        await PigeonPlacesPlatform(
          api: api,
          platform: p,
        ).findPredictions('a', options: options);
        expect(api.initKeys, [null], reason: '$p');
      }
    });

    test('platform defaults to the target platform', () async {
      for (final target in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = target;
        final api = _Api();
        await PigeonPlacesPlatform(api: api)
            .findPredictions('a', options: options);
        expect(api.initKeys, [null], reason: '$target');
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
