// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// `FlPlaceAutocompleteCore` is pure Swift (Foundation only) so its unit tests can
// run on macOS with `swift test`. The Flutter/Places plugin target needs the
// Flutter-generated `../FlutterFramework` package and the iOS-only GooglePlaces
// binary, so setting FL_PLACE_AUTOCOMPLETE_CORE_ONLY=1 drops them:
//
//   FL_PLACE_AUTOCOMPLETE_CORE_ONLY=1 swift test --package-path ios/fl_place_autocomplete_ios
//
// Flutter/Xcode builds never set the variable and get the full plugin.
let coreOnly = ProcessInfo.processInfo.environment["FL_PLACE_AUTOCOMPLETE_CORE_ONLY"] == "1"

let coreTargets: [Target] = [
    .target(name: "FlPlaceAutocompleteCore"),
    .testTarget(name: "FlPlaceAutocompleteCoreTests", dependencies: ["FlPlaceAutocompleteCore"]),
]

let pluginTarget: Target = .target(
    name: "fl_place_autocomplete_ios",
    dependencies: [
        "FlPlaceAutocompleteCore",
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "GooglePlaces", package: "ios-places-sdk"),
    ],
    resources: [
        .process("PrivacyInfo.xcprivacy"),
    ]
)

let package = Package(
    name: "fl_place_autocomplete_ios",
    platforms: coreOnly ? [.iOS("16.0"), .macOS("10.15")] : [.iOS("16.0")],
    products: coreOnly
        ? [.library(name: "FlPlaceAutocompleteCore", targets: ["FlPlaceAutocompleteCore"])]
        : [.library(name: "fl-place-autocomplete-ios", targets: ["fl_place_autocomplete_ios"])],
    dependencies: coreOnly
        ? []
        : [
            .package(name: "FlutterFramework", path: "../FlutterFramework"),
            .package(url: "https://github.com/googlemaps/ios-places-sdk", from: "11.2.0"),
        ],
    targets: coreOnly ? coreTargets : coreTargets + [pluginTarget]
)
