import FlPlaceAutocompleteCore
import Flutter
import GooglePlaces
import UIKit

/// Places SDK for iOS (New) implementation of the Pigeon `PlacesHostApi`.
///
/// The API key is read from the `GMSPlacesAPIKey` Info.plist entry.
/// The iOS SDK has no per-request language: results use the device/app locale,
/// so `languageCode` is ignored.
///
/// Threading: `GMSPlacesClient` must only be used from the main thread, so every
/// method touching the SDK is `@MainActor` (Pigeon already invokes the handlers
/// from a main-actor task; the annotation keeps the async bodies there too).
/// The session and photo stores are lock-protected.
public final class FlPlaceAutocompleteIosPlugin: NSObject, FlutterPlugin, PlacesHostApi {
    private static let apiKeyInfoPlistKey = "GMSPlacesAPIKey"

    private let sessions = SessionStore<GMSAutocompleteSessionToken> { GMSAutocompleteSessionToken() }
    private let photos = PhotoStore<GMSPlacePhotoMetadata>()
    /// `provideAPIKey` is process-wide; call it at most once (main actor only).
    @MainActor private static var keyProvided = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        PlacesHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: FlPlaceAutocompleteIosPlugin())
    }

    // MARK: Setup & errors

    @MainActor
    private func client() throws -> GMSPlacesClient {
        if !Self.keyProvided {
            guard let key = Bundle.main.object(forInfoDictionaryKey: Self.apiKeyInfoPlistKey) as? String,
                  !key.trimmingCharacters(in: .whitespaces).isEmpty
            else {
                throw PigeonError(code: "invalidApiKey", message: "Missing \(Self.apiKeyInfoPlistKey) in Info.plist", details: nil)
            }
            // Returns false when a key was already provided (e.g. by another plugin); that key is reused.
            _ = GMSPlacesClient.provideAPIKey(key)
            Self.keyProvided = true
        }
        return GMSPlacesClient.shared()
    }

    /// Translates SDK/system failures into `PigeonError`s carrying Dart error codes.
    private func pigeonError(_ error: Error) -> PigeonError {
        if let error = error as? PigeonError { return error }
        let nsError = error as NSError
        return PigeonError(
            code: ErrorMapper.code(for: nsError, placesDomain: kGMSPlacesErrorDomain),
            message: nsError.localizedDescription,
            details: nil
        )
    }

    /// Bridges a callback-based SDK call to async/await, mapping failures.
    /// The continuation is resumed exactly once even if the SDK called back twice.
    @MainActor
    private func call<T>(_ body: (@escaping (T?, Error?) -> Void) -> Void, missing: PigeonError) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            var resumed = false
            body { value, error in
                guard !resumed else { return }
                resumed = true
                if let error {
                    continuation.resume(throwing: self.pigeonError(error))
                } else if let value {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: missing)
                }
            }
        }
    }

    // MARK: PlacesHostApi

    @MainActor
    func initialize() async throws {
        do { _ = try client() } catch { throw pigeonError(error) }
    }

    func disposeSession(sessionId: String) throws {
        sessions.remove(sessionId)
    }

    @MainActor
    func findPredictions(input: String, sessionId: String?, options: OptionsMsg) async throws -> [PredictionMsg] {
        let client: GMSPlacesClient
        do { client = try self.client() } catch { throw pigeonError(error) }

        let filter = GMSAutocompleteFilter()
        if let bias = options.locationBias?.toBias() { filter.locationBias = bias }
        if let restriction = options.locationRestriction { filter.locationRestriction = restriction.toRectangle() }
        if let origin = options.origin { filter.origin = CLLocation(latitude: origin.latitude, longitude: origin.longitude) }
        if !options.includedPrimaryTypes.isEmpty { filter.types = options.includedPrimaryTypes }
        if !options.includedRegionCodes.isEmpty { filter.countries = options.includedRegionCodes }
        if let regionCode = options.regionCode { filter.regionCode = regionCode }
        if let offset = options.inputOffset { filter.inputOffset = Int32(clamping: offset) }
        // options.languageCode: no per-request language on iOS (see class doc).

        let request = GMSAutocompleteRequest(query: input)
        request.sessionToken = sessions.getOrNil(sessionId)
        request.filter = filter

        let suggestions: [GMSAutocompleteSuggestion] = try await call(
            { done in client.fetchAutocompleteSuggestions(from: request) { done($0 ?? [], $1) } },
            missing: PigeonError(code: "unknown", message: "No suggestions returned", details: nil)
        )
        return suggestions.compactMap { $0.placeSuggestion?.toMsg() }
    }

    @MainActor
    func fetchPlace(placeId: String, sessionId: String?, fields: [String], languageCode: String?, regionCode: String?) async throws -> PlaceMsg {
        let client: GMSPlacesClient
        do { client = try self.client() } catch { throw pigeonError(error) }

        var properties: [GMSPlaceProperty] = []
        for property in fields.compactMap(propertyFor) where !properties.contains(property) {
            properties.append(property)
        }
        // A request needs at least one property; the ID is always available.
        if properties.isEmpty { properties = [.placeID] }
        // regionCode / languageCode: GMSFetchPlaceRequest has neither in SDK 11.x.

        let request = GMSFetchPlaceRequest(
            placeID: placeId,
            placeProperties: properties.map { $0.rawValue },
            sessionToken: sessions.getOrNil(sessionId)
        )
        // A failed fetch throws here and keeps the session usable.
        let place: GMSPlace = try await call(
            { done in client.fetchPlace(with: request, callback: done) },
            missing: PigeonError(code: "notFound", message: "Place \(placeId) not found", details: nil)
        )
        // Place Details ends the session, but only on success.
        if let sessionId { sessions.remove(sessionId) }
        return place.toMsg(requested: Set(fields), photos: photos)
    }

    @MainActor
    func fetchPhoto(ref: PhotoRefMsg, maxWidth: Int64?, maxHeight: Int64?) async throws -> PhotoDataMsg {
        let client: GMSPlacesClient
        do { client = try self.client() } catch { throw pigeonError(error) }
        guard let metadata = photos.get(ref.id) else {
            throw PigeonError(code: "notFound", message: "Unknown photo id \(ref.id); fetch the place again.", details: nil)
        }
        let fallback: CGFloat = 1600
        let size = CGSize(
            width: maxWidth.map { CGFloat($0) } ?? (metadata.maxSize.width > 0 ? metadata.maxSize.width : fallback),
            height: maxHeight.map { CGFloat($0) } ?? (metadata.maxSize.height > 0 ? metadata.maxSize.height : fallback)
        )
        let request = GMSFetchPhotoRequest(photoMetadata: metadata, maxSize: size)
        let image: UIImage = try await call(
            { done in client.fetchPhoto(with: request, callback: done) },
            missing: PigeonError(code: "unknown", message: "Photo had no image data", details: nil)
        )
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw PigeonError(code: "unknown", message: "Could not encode photo", details: nil)
        }
        return PhotoDataMsg(bytes: FlutterStandardTypedData(bytes: data), uri: nil)
    }
}
