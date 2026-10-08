// ignore_for_file: public_member_api_docs
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fl_place_autocomplete_android_method_channel.dart';

abstract class FlPlaceAutocompleteAndroidPlatform extends PlatformInterface {
  /// Constructs a FlPlaceAutocompleteAndroidPlatform.
  FlPlaceAutocompleteAndroidPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlPlaceAutocompleteAndroidPlatform _instance = MethodChannelFlPlaceAutocompleteAndroid();

  /// The default instance of [FlPlaceAutocompleteAndroidPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlPlaceAutocompleteAndroid].
  static FlPlaceAutocompleteAndroidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlPlaceAutocompleteAndroidPlatform] when
  /// they register themselves.
  static set instance(FlPlaceAutocompleteAndroidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
