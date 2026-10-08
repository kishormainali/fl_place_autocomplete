import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_platform.dart';

void main() {
  late FakePlatform platform;
  late FlPlaceAutocomplete api;
  setUp(() {
    platform = FakePlatform();
    api = FlPlaceAutocomplete(platform: platform);
  });

  test('blank input returns empty without a platform call', () async {
    expect(await api.findPredictions('   '), isEmpty);
    expect(platform.totalCalls, 0);
  });

  test('same session id is used for every request in a session', () async {
    final s = api.newSession();
    await api.findPredictions('pi', session: s);
    await api.findPredictions('piz', session: s);
    expect(platform.findCalls.map((c) => c.sessionId).toSet(), {s.id});
  });

  test('no session means no session id is sent', () async {
    await api.findPredictions('pi');
    expect(platform.findCalls.single.sessionId, isNull);
  });

  test('fetchPlace ends the session; reuse throws StateError', () async {
    final s = api.newSession();
    await api.findPredictions('pi', session: s);
    final place = await api.fetchPlace('p1', session: s, fields: {PlaceField.location});
    expect(place.location, const LatLng(1, 2));
    expect(platform.fetchCalls.single.sessionId, s.id);
    expect(s.isEnded, isTrue);
    expect(() => api.findPredictions('x', session: s), throwsStateError);
    expect(() => api.fetchPlace('p1', session: s, fields: {PlaceField.id}), throwsStateError);
  });

  test('fetchPlace failure leaves the session active so it can be retried', () async {
    final s = api.newSession();
    platform.onFetch = (_) => Future.error(const PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.networkError));
    await expectLater(api.fetchPlace('p', session: s, fields: {PlaceField.id}), throwsA(isA<PlaceAutocompleteException>()));
    expect(s.isEnded, isFalse);
    platform.onFetch = null;
    await api.fetchPlace('p', session: s, fields: {PlaceField.id});
    expect(s.isEnded, isTrue);
  });

  test('empty fields is rejected', () {
    expect(() => api.fetchPlace('p', fields: {}), throwsArgumentError);
  });

  test('cancelSession ends and disposes once', () async {
    final s = api.newSession();
    await api.cancelSession(s);
    await api.cancelSession(s);
    expect(platform.disposed, [s.id]);
    expect(s.isEnded, isTrue);
  });
}
