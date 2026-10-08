import 'package:flutter_test/flutter_test.dart';
import 'package:fl_place_autocomplete_android/fl_place_autocomplete_android.dart';
import 'package:fl_place_autocomplete_android/fl_place_autocomplete_android_platform_interface.dart';
import 'package:fl_place_autocomplete_android/fl_place_autocomplete_android_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlPlaceAutocompleteAndroidPlatform
    with MockPlatformInterfaceMixin
    implements FlPlaceAutocompleteAndroidPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlPlaceAutocompleteAndroidPlatform initialPlatform = FlPlaceAutocompleteAndroidPlatform.instance;

  test('$MethodChannelFlPlaceAutocompleteAndroid is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlPlaceAutocompleteAndroid>());
  });

  test('getPlatformVersion', () async {
    FlPlaceAutocompleteAndroid flPlaceAutocompleteAndroidPlugin = FlPlaceAutocompleteAndroid();
    MockFlPlaceAutocompleteAndroidPlatform fakePlatform = MockFlPlaceAutocompleteAndroidPlatform();
    FlPlaceAutocompleteAndroidPlatform.instance = fakePlatform;

    expect(await flPlaceAutocompleteAndroidPlugin.getPlatformVersion(), '42');
  });
}
