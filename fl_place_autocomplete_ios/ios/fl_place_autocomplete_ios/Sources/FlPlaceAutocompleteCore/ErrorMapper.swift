import Foundation

/// Maps native failures to `PlaceAutocompleteErrorCode` names on the Dart side
/// (`invalidApiKey`, `quotaExceeded`, `networkError`, `invalidRequest`,
/// `notFound`, `unknown`).
///
/// Dependency-free: the Places error domain string is passed in by the plugin
/// (`kGMSPlacesErrorDomain`), and the numeric codes mirror `GMSPlacesErrorCode`.
public enum ErrorMapper {
    /// Maps an `NSError`. Places SDK codes win; codes without a direct
    /// equivalent (server/internal errors) and foreign domains fall back to
    /// `code(forMessage:)`.
    public static func code(for error: NSError, placesDomain: String) -> String {
        if error.domain == placesDomain, let mapped = code(forPlacesErrorCode: error.code) {
            return mapped
        }
        if error.domain == NSURLErrorDomain { return "networkError" }
        return code(forMessage: error.localizedDescription)
    }

    /// `GMSPlacesErrorCode` raw value to a Dart code, or `nil` when the code
    /// alone is not specific enough.
    public static func code(forPlacesErrorCode code: Int) -> String? {
        switch code {
        case -1: return "networkError"                  // kGMSPlacesNetworkError
        case -4, -5, -9, -10: return "invalidApiKey"     // KeyInvalid, KeyExpired, AccessNotConfigured, IncorrectBundleIdentifier
        case -6, -7, -8: return "quotaExceeded"          // UsageLimit, RateLimit, DeviceRateLimit
        case -12: return "invalidRequest"                // kGMSPlacesInvalidRequest
        default: return nil                              // ServerError, InternalError, LocationError, unknown
        }
    }

    /// Heuristic fallback over the error message.
    public static func code(forMessage message: String) -> String {
        let m = message.lowercased()
        if m.contains("api key") || m.contains("apikey") || m.contains("request denied") || m.contains("request_denied") {
            return "invalidApiKey"
        }
        if m.contains("quota") || m.contains("over query") || m.contains("over_query") || m.contains("rate limit") {
            return "quotaExceeded"
        }
        if m.contains("internet") || m.contains("network") || m.contains("offline") { return "networkError" }
        if m.contains("not found") || m.contains("not_found") { return "notFound" }
        if m.contains("invalid") { return "invalidRequest" }
        return "unknown"
    }
}
