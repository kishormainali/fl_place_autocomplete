import Foundation

/// Chooses the Places API key: the Dart (`--dart-define`) key first, then Info.plist.
public enum KeyResolver {
    /// Error message when neither a Dart key nor `GMSPlacesAPIKey` is set.
    public static let missingKeyMessage =
        "No Google Places API key. Pass --dart-define=GOOGLE_PLACES_API_KEY=<key> "
        + "(or GOOGLE_PLACES_API_KEY_IOS) to flutter run/build, or add a "
        + "GMSPlacesAPIKey string entry to the app's Info.plist."

    /// Returns the first non-blank of `explicit` and `fallback`, trimmed, or nil.
    public static func pick(_ explicit: String?, _ fallback: String?) -> String? {
        nonBlank(explicit) ?? nonBlank(fallback)
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
