import 'package:flutter_test/flutter_test.dart';
import 'package:fl_place_autocomplete_web/fl_place_autocomplete_web.dart';
import 'package:fl_place_autocomplete_web/fl_place_autocomplete_web_platform_interface.dart';
import 'package:fl_place_autocomplete_web/fl_place_autocomplete_web_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlPlaceAutocompleteWebPlatform
    with MockPlatformInterfaceMixin
    implements FlPlaceAutocompleteWebPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlPlaceAutocompleteWebPlatform initialPlatform =
      FlPlaceAutocompleteWebPlatform.instance;

  test('$MethodChannelFlPlaceAutocompleteWeb is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelFlPlaceAutocompleteWeb>(),
    );
  });

  test('getPlatformVersion', () async {
    FlPlaceAutocompleteWeb flPlaceAutocompleteWebPlugin =
        FlPlaceAutocompleteWeb();
    MockFlPlaceAutocompleteWebPlatform fakePlatform =
        MockFlPlaceAutocompleteWebPlatform();
    FlPlaceAutocompleteWebPlatform.instance = fakePlatform;

    expect(await flPlaceAutocompleteWebPlugin.getPlatformVersion(), '42');
  });
}
