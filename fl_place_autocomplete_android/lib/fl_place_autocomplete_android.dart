import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';

/// Android implementation of `fl_place_autocomplete`.
///
/// Backed by the Places SDK for Android (New) through the shared Pigeon
/// host API; Flutter registers it automatically via `dartPluginClass`.
class FlPlaceAutocompleteAndroid {
  /// Registers the Pigeon-backed implementation as the platform instance.
  static void registerWith() {
    FlPlaceAutocompletePlatform.instance = PigeonPlacesPlatform(
      platform: PlacesApiPlatform.android,
    );
  }
}
