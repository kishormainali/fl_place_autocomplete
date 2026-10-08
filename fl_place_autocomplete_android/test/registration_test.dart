import 'package:fl_place_autocomplete_android/fl_place_autocomplete_android.dart';
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registerWith installs the Pigeon platform', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlPlaceAutocompleteAndroid.registerWith();
    expect(FlPlaceAutocompletePlatform.instance, isA<PigeonPlacesPlatform>());
  });
}
