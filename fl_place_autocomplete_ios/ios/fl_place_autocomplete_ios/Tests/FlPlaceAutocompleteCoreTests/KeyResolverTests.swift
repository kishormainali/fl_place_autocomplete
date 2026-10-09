import XCTest
@testable import FlPlaceAutocompleteCore

final class KeyResolverTests: XCTestCase {
    func testExplicitKeyWins() {
        XCTAssertEqual(KeyResolver.pick("dart", "plist"), "dart")
    }

    func testBlankExplicitFallsBackToNativeConfig() {
        for blank in [nil, "", "   ", "\t\n"] as [String?] {
            XCTAssertEqual(KeyResolver.pick(blank, "plist"), "plist", "explicit=\(String(describing: blank))")
        }
    }

    func testNilWhenBothBlank() {
        XCTAssertNil(KeyResolver.pick(nil, nil))
        XCTAssertNil(KeyResolver.pick(" ", ""))
    }

    func testValuesAreTrimmed() {
        XCTAssertEqual(KeyResolver.pick("  k ", nil), "k")
        XCTAssertEqual(KeyResolver.pick(nil, " p\n"), "p")
    }

    func testMissingKeyMessageNamesBothOptions() {
        XCTAssertTrue(KeyResolver.missingKeyMessage.contains("--dart-define=GOOGLE_PLACES_API_KEY"))
        XCTAssertTrue(KeyResolver.missingKeyMessage.contains("GMSPlacesAPIKey"))
    }
}
