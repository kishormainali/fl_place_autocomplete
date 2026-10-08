import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlaceField.apiName equals enum name for every field', () {
    for (final f in PlaceField.values) {
      expect(f.apiName, f.name);
    }
    expect(PlaceField.values.length, 23);
  });

  test('Place with no data is valid and all fields are null', () {
    const p = Place();
    expect(p.location, isNull);
    expect(p.photos, isNull);
    expect(p.displayName, isNull);
  });

  test('Place exposes location as LatLng', () {
    const p = Place(location: LatLng(1.5, 2.5));
    expect(p.location!.latitude, 1.5);
    expect(p.location!.longitude, 2.5);
  });
}
