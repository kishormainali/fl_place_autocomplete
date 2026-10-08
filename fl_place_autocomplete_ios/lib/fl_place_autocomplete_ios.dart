import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';

/// iOS implementation of `fl_place_autocomplete`.
///
/// Backed by the Places SDK for iOS (New) through the shared Pigeon host API;
/// Flutter registers it automatically via `dartPluginClass`.
class FlPlaceAutocompleteIos {
  /// Registers the Pigeon-backed implementation as the platform instance.
  static void registerWith() {
    FlPlaceAutocompletePlatform.instance = PigeonPlacesPlatform();
  }
}
