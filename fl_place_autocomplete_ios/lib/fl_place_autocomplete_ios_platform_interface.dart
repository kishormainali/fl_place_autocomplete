// ignore_for_file: public_member_api_docs
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fl_place_autocomplete_ios_method_channel.dart';

abstract class FlPlaceAutocompleteIosPlatform extends PlatformInterface {
  /// Constructs a FlPlaceAutocompleteIosPlatform.
  FlPlaceAutocompleteIosPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlPlaceAutocompleteIosPlatform _instance = MethodChannelFlPlaceAutocompleteIos();

  /// The default instance of [FlPlaceAutocompleteIosPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlPlaceAutocompleteIos].
  static FlPlaceAutocompleteIosPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlPlaceAutocompleteIosPlatform] when
  /// they register themselves.
  static set instance(FlPlaceAutocompleteIosPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
