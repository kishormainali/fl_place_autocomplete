// ignore_for_file: public_member_api_docs

import 'fl_place_autocomplete_web_platform_interface.dart';

class FlPlaceAutocompleteWeb {
  Future<String?> getPlatformVersion() {
    return FlPlaceAutocompleteWebPlatform.instance.getPlatformVersion();
  }
}
