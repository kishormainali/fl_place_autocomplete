// ignore_for_file: public_member_api_docs

import 'fl_place_autocomplete_android_platform_interface.dart';

class FlPlaceAutocompleteAndroid {
  Future<String?> getPlatformVersion() {
    return FlPlaceAutocompleteAndroidPlatform.instance.getPlatformVersion();
  }
}
