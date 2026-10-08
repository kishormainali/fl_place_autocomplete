import 'package:fl_place_autocomplete_ios/fl_place_autocomplete_ios.dart';
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registerWith installs the Pigeon platform', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlPlaceAutocompleteIos.registerWith();
    expect(FlPlaceAutocompletePlatform.instance, isA<PigeonPlacesPlatform>());
  });
}
