// ignore_for_file: public_member_api_docs
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fl_place_autocomplete_web_method_channel.dart';

abstract class FlPlaceAutocompleteWebPlatform extends PlatformInterface {
  /// Constructs a FlPlaceAutocompleteWebPlatform.
  FlPlaceAutocompleteWebPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlPlaceAutocompleteWebPlatform _instance =
      MethodChannelFlPlaceAutocompleteWeb();

  /// The default instance of [FlPlaceAutocompleteWebPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlPlaceAutocompleteWeb].
  static FlPlaceAutocompleteWebPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlPlaceAutocompleteWebPlatform] when
  /// they register themselves.
  static set instance(FlPlaceAutocompleteWebPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
