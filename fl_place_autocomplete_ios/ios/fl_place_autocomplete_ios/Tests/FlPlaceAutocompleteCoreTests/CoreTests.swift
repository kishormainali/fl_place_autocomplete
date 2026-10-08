import Foundation
import XCTest
@testable import FlPlaceAutocompleteCore

final class CoreTests: XCTestCase {
    // MARK: SessionStore

    func testSessionStoreReusesAndRemoves() {
        var n = 0
        let store = SessionStore<String> { n += 1; return "t\(n)" }
        let a = store.getOrCreate("a")
        XCTAssertEqual(a, store.getOrCreate("a"))
        XCTAssertNotEqual(a, store.getOrCreate("b"))
        store.remove("a")
        XCTAssertNotEqual(a, store.getOrCreate("a"))
        XCTAssertNil(store.getOrNil(nil))
        XCTAssertEqual(store.getOrNil("b"), store.getOrCreate("b"))
    }

    func testSessionStoreRemoveUnknownIsNoOp() {
        let store = SessionStore<Int> { 1 }
        store.remove("missing")
        XCTAssertEqual(store.getOrCreate("x"), 1)
    }

    // MARK: ErrorMapper (message fallback)

    func testErrorCodesFromMessage() {
        XCTAssertEqual(ErrorMapper.code(forMessage: "API key not valid"), "invalidApiKey")
        XCTAssertEqual(ErrorMapper.code(forMessage: "REQUEST_DENIED"), "invalidApiKey")
        XCTAssertEqual(ErrorMapper.code(forMessage: "Quota exceeded"), "quotaExceeded")
        XCTAssertEqual(ErrorMapper.code(forMessage: "The Internet connection appears to be offline"), "networkError")
        XCTAssertEqual(ErrorMapper.code(forMessage: "not found"), "notFound")
        XCTAssertEqual(ErrorMapper.code(forMessage: "NOT_FOUND: place id"), "notFound")
        XCTAssertEqual(ErrorMapper.code(forMessage: "invalid argument"), "invalidRequest")
        XCTAssertEqual(ErrorMapper.code(forMessage: "boom"), "unknown")
    }

    // MARK: ErrorMapper (NSError domain/code)

    private let places = "com.google.places.ErrorDomain"

    private func err(_ domain: String, _ code: Int, _ message: String = "x") -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    func testPlacesErrorCodes() {
        let cases: [(Int, String)] = [
            (-1, "networkError"),       // kGMSPlacesNetworkError
            (-4, "invalidApiKey"),      // kGMSPlacesKeyInvalid
            (-5, "invalidApiKey"),      // kGMSPlacesKeyExpired
            (-6, "quotaExceeded"),      // kGMSPlacesUsageLimitExceeded
            (-7, "quotaExceeded"),      // kGMSPlacesRateLimitExceeded
            (-8, "quotaExceeded"),      // kGMSPlacesDeviceRateLimitExceeded
            (-9, "invalidApiKey"),      // kGMSPlacesAccessNotConfigured
            (-10, "invalidApiKey"),     // kGMSPlacesIncorrectBundleIdentifier
            (-12, "invalidRequest"),    // kGMSPlacesInvalidRequest
        ]
        for (code, expected) in cases {
            XCTAssertEqual(ErrorMapper.code(for: err(places, code), placesDomain: places), expected, "code \(code)")
        }
    }

    func testPlacesServerErrorFallsBackToMessage() {
        XCTAssertEqual(ErrorMapper.code(for: err(places, -2, "NOT_FOUND"), placesDomain: places), "notFound")
        XCTAssertEqual(ErrorMapper.code(for: err(places, -2, "boom"), placesDomain: places), "unknown")
        XCTAssertEqual(ErrorMapper.code(for: err(places, -3, "boom"), placesDomain: places), "unknown")
    }

    func testUrlErrorsAreNetworkErrors() {
        XCTAssertEqual(ErrorMapper.code(for: err(NSURLErrorDomain, NSURLErrorTimedOut), placesDomain: places), "networkError")
        XCTAssertEqual(ErrorMapper.code(for: err(NSURLErrorDomain, NSURLErrorNotConnectedToInternet), placesDomain: places), "networkError")
    }

    func testOtherDomainsUseMessage() {
        XCTAssertEqual(ErrorMapper.code(for: err("Other", -4, "quota"), placesDomain: places), "quotaExceeded")
        XCTAssertEqual(ErrorMapper.code(for: err("Other", -4, "boom"), placesDomain: places), "unknown")
    }

    // MARK: Ranges

    func testRangesUseUTF16Offsets() {
        let s = "🍕 Pizza"
        let attributed = NSMutableAttributedString(string: s)
        let key = NSAttributedString.Key("matched")
        attributed.addAttribute(key, value: 1, range: NSRange(location: 3, length: 5))
        let ranges = Ranges.matched(in: attributed, attribute: key)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].start, 3)
        XCTAssertEqual(ranges[0].end, 8) // end offset in UTF-16 units, not Character count
        XCTAssertEqual(s.count, 7)       // Swift Character count differs: confirms we must not use it
    }

    func testRangesMultipleAndNone() {
        let attributed = NSMutableAttributedString(string: "Pizza Pizzeria")
        let key = NSAttributedString.Key("matched")
        XCTAssertTrue(Ranges.matched(in: attributed, attribute: key).isEmpty)
        attributed.addAttribute(key, value: true, range: NSRange(location: 0, length: 3))
        attributed.addAttribute(key, value: true, range: NSRange(location: 6, length: 3))
        let ranges = Ranges.matched(in: attributed, attribute: key)
        XCTAssertEqual(ranges.map(\.start), [0, 6])
        XCTAssertEqual(ranges.map(\.end), [3, 9])
    }

    // MARK: PhotoStore

    func testPhotoStoreReturnsStoredValueById() {
        let store = PhotoStore<String>(capacity: 2)
        let a = store.put("a")
        let b = store.put("b")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(store.get(a), "a")
        XCTAssertEqual(store.get(b), "b")
        XCTAssertNil(store.get("missing"))
    }

    func testPhotoStoreEvictsLeastRecentlyUsed() {
        let store = PhotoStore<String>(capacity: 2)
        let a = store.put("a")
        let b = store.put("b")
        XCTAssertEqual(store.get(a), "a") // touch a: b is now least recently used
        let c = store.put("c")
        XCTAssertNil(store.get(b))
        XCTAssertEqual(store.get(a), "a")
        XCTAssertEqual(store.get(c), "c")
    }
}
