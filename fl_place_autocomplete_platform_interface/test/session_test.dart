import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create() yields unique 32-char hex ids', () {
    final ids = {for (var i = 0; i < 100; i++) PlaceSession.create().id};
    expect(ids.length, 100);
    expect(ids.every((id) => RegExp(r'^[0-9a-f]{32}$').hasMatch(id)), isTrue);
  });

  test('end() is idempotent and ensureActive throws StateError afterwards', () {
    final s = PlaceSession.withId('a');
    s.ensureActive();
    s.end();
    s.end();
    expect(s.isEnded, isTrue);
    expect(s.ensureActive, throwsStateError);
  });

  test('default platform methods throw UnimplementedError', () {
    expect(
      () => FlPlaceAutocompletePlatform.instance.findPredictions('x', options: PredictionOptions()),
      throwsUnimplementedError,
    );
  });
}
