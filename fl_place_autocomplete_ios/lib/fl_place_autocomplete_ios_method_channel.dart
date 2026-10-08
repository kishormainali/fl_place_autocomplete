// ignore_for_file: public_member_api_docs
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fl_place_autocomplete_ios_platform_interface.dart';

/// An implementation of [FlPlaceAutocompleteIosPlatform] that uses method channels.
class MethodChannelFlPlaceAutocompleteIos extends FlPlaceAutocompleteIosPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fl_place_autocomplete_ios');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
