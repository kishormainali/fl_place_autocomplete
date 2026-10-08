// ignore_for_file: public_member_api_docs

import 'fl_place_autocomplete_ios_platform_interface.dart';

class FlPlaceAutocompleteIos {
  Future<String?> getPlatformVersion() {
    return FlPlaceAutocompleteIosPlatform.instance.getPlatformVersion();
  }
}
