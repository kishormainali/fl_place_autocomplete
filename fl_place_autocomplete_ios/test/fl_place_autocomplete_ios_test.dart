import 'package:flutter_test/flutter_test.dart';
import 'package:fl_place_autocomplete_ios/fl_place_autocomplete_ios.dart';
import 'package:fl_place_autocomplete_ios/fl_place_autocomplete_ios_platform_interface.dart';
import 'package:fl_place_autocomplete_ios/fl_place_autocomplete_ios_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlPlaceAutocompleteIosPlatform
    with MockPlatformInterfaceMixin
    implements FlPlaceAutocompleteIosPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlPlaceAutocompleteIosPlatform initialPlatform = FlPlaceAutocompleteIosPlatform.instance;

  test('$MethodChannelFlPlaceAutocompleteIos is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlPlaceAutocompleteIos>());
  });

  test('getPlatformVersion', () async {
    FlPlaceAutocompleteIos flPlaceAutocompleteIosPlugin = FlPlaceAutocompleteIos();
    MockFlPlaceAutocompleteIosPlatform fakePlatform = MockFlPlaceAutocompleteIosPlatform();
    FlPlaceAutocompleteIosPlatform.instance = fakePlatform;

    expect(await flPlaceAutocompleteIosPlugin.getPlatformVersion(), '42');
  });
}
