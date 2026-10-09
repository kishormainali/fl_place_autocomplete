# fl_place_autocomplete Milestone 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the federated `fl_place_autocomplete` plugin (platform interface, Android, iOS-SPM, web, app-facing package) with the new Places API, correct session handling, a fully customizable `PlaceAutocompleteField`, full place details on selection, photo fetch, example app and CI.

**Architecture:** One Pigeon schema generates the shared Dart host-API client (in `platform_interface`), the Kotlin interface (Android) and the Swift protocol (iOS). Dart owns session IDs (random opaque strings); each native side lazily maps an ID to its real session token. Web talks to the Maps JS `places` library directly via `dart:js_interop`. The widget is pure Dart on top of a `PlaceAutocompleteController` that contains all behaviour (debounce, stale-response dropping, session lifecycle, initial-value rule).

**Tech Stack:** Flutter 3.47 / Dart 3.13, melos (pub workspace), Pigeon 29.x, Kotlin + Places SDK for Android (New), Swift + GooglePlaces via SwiftPM, `dart:js_interop` + `package:web`, `plugin_platform_interface`.

**Spec:** `docs/superpowers/specs/2026-10-08-fl-place-autocomplete-design.md`

## Global Constraints

- Packages: `fl_place_autocomplete`, `fl_place_autocomplete_platform_interface`, `fl_place_autocomplete_android`, `fl_place_autocomplete_ios`, `fl_place_autocomplete_web`, one melos monorepo.
- New Places API everywhere: Android `Places.initializeWithNewPlacesApiEnabled` (Places SDK for Android >= 3.5), iOS `GMSAutocompleteRequest` / `GMSFetchPlaceRequest`, web `AutocompleteSuggestion.fetchAutocompleteSuggestions` + `Place.fetchFields`.
- iOS is **SwiftPM only**: no podspec, `Package.swift` depends on `https://github.com/googlemaps/ios-places-sdk` product `GooglePlaces`; minimum iOS 16; require Flutter >= 3.44; `ios-places-sdk` `from: "11.2.0"` (latest 11.x).
- API key (amended 2026-10-08, Task 15; was "No API key in Dart"): resolved in Dart from `--dart-define` (`GOOGLE_PLACES_API_KEY_ANDROID|_IOS|_WEB`, then `GOOGLE_PLACES_API_KEY`) and passed to natives via Pigeon `initialize(String? apiKey)`; native config stays the fallback: AndroidManifest meta-data `com.google.android.geo.API_KEY`, Info.plist `GMSPlacesAPIKey`, web Maps JS already loaded by `index.html` (else the plugin injects the bootstrap loader with the define key).
- Session rules: session starts at first autocomplete request, every request reuses the token, `fetchPlace` ends it (only on success), an ended `PlaceSession` throws `StateError` on reuse, abandoned sessions are disposed.
- Limits validated in Dart: `includedPrimaryTypes` <= 5, `includedRegionCodes` <= 15, bias radius in (0, 50000], bias and restriction are mutually exclusive, `locationRestriction` is a rectangle only, `fields` must be non-empty.
- Initial value / `setText` / `setPlace` / focus never trigger a Places API call.
- Widget defaults: debounce 300 ms, `minChars` 2, `fetchDetailsOnSelect` true, default fields `location`, `displayName`, `formattedAddress`; default footer shows "Powered by Google".
- Dart sessions are created in Dart (`PlaceSession.create()`), so `newSession()` is synchronous. There is no `createSession` Pigeon method (refinement of spec §7; natives create tokens lazily by ID).
- Kotlin/Swift package id: `com.mk7.fl_place_autocomplete_android`; iOS plugin class `FlPlaceAutocompleteIosPlugin`; Android plugin class `FlPlaceAutocompleteAndroidPlugin`.
- Git commit messages contain **no** Claude/Co-Authored-By attribution lines.

## Review Focus

1. Stale response after selection or newer keystroke must not reopen the overlay, overwrite text, or set `selectedPlace` (Task 7 tests).
2. `fetchPlace` failure: session must stay active (not ended), error surfaced via `onError`/`errorBuilder`, retry works (Tasks 6 and 7 tests).
3. Prediction with empty `secondaryText`, empty `primaryText`, or matched ranges out of bounds must not throw in the default tile (Task 2 `matchesWithin` tests, Task 8 tile test).
4. Matched-range offsets are UTF-16 code units; emoji / non-BMP text must map correctly, and iOS must convert from `NSRange` not Swift `String` indices (Task 2 test, Task 12 Swift test).
5. Widget disposed mid-debounce or mid-request, and blur while the selection fetch is in flight, must not throw or cancel the in-flight selection (Task 7 tests).

---

## File Structure

```
pubspec.yaml                                  workspace + melos scripts
analysis_options.yaml
.github/workflows/ci.yml
fl_place_autocomplete_platform_interface/
  pigeons/messages.dart                       Pigeon schema (generates Dart, Kotlin, Swift)
  lib/fl_place_autocomplete_platform_interface.dart
  lib/src/models/{lat_lng,prediction_options,place_prediction,place_field,place,photo}.dart
  lib/src/{place_session,exceptions,platform}.dart
  lib/src/pigeon/{messages.g.dart,mappers.dart,pigeon_platform.dart}
  test/...
fl_place_autocomplete/                        app-facing (Flutter package, federated endorsement)
  lib/fl_place_autocomplete.dart
  lib/src/api.dart
  lib/src/widget/{controller,field,default_builders}.dart
  test/{support/fake_platform,api_test,controller_test,field_test}.dart
fl_place_autocomplete_android/                Kotlin
fl_place_autocomplete_ios/                    Swift, SwiftPM
fl_place_autocomplete_web/                    Dart js_interop
fl_place_autocomplete/example/                example app
```

---

### Task 1: Workspace scaffold

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `LICENSE`
- Create (via `flutter create`): the five packages

**Interfaces:**
- Produces: five buildable empty packages wired into a pub workspace; `melos run <script>` available.

- [ ] **Step 1: Create the packages**

```bash
cd /Users/mk7/development/oss-projects/fl_place_autocomplete
flutter create --template=package fl_place_autocomplete_platform_interface
flutter create --template=package fl_place_autocomplete
flutter create --template=plugin --platforms=android -a kotlin --org com.mk7 fl_place_autocomplete_android
flutter create --template=plugin --platforms=ios -i swift --org com.mk7 fl_place_autocomplete_ios
flutter create --template=plugin --platforms=web --org com.mk7 fl_place_autocomplete_web
ls fl_place_autocomplete_ios/ios fl_place_autocomplete_android/android/src/main/kotlin/com/mk7
```
Expected: the iOS package contains `ios/fl_place_autocomplete_ios/Package.swift` (SwiftPM layout) and probably a `.podspec`; the Android package dir is `com/mk7/fl_place_autocomplete_android`. If iOS did not generate a SwiftPM layout, create it by hand in Task 11.

- [ ] **Step 2: Delete the iOS podspec and generated example apps of implementation packages**

```bash
rm -f fl_place_autocomplete_ios/ios/*.podspec
rm -rf fl_place_autocomplete_android/example fl_place_autocomplete_ios/example fl_place_autocomplete_web/example fl_place_autocomplete_platform_interface/example
rm -rf fl_place_autocomplete/test/*.dart 2>/dev/null; true
```
(The only example app lives under `fl_place_autocomplete/example`, created in Task 13.)

- [ ] **Step 3: Root workspace `pubspec.yaml`**

```yaml
name: fl_place_autocomplete_workspace
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - fl_place_autocomplete
  - fl_place_autocomplete_platform_interface
  - fl_place_autocomplete_android
  - fl_place_autocomplete_ios
  - fl_place_autocomplete_web
dev_dependencies:
  melos: ^7.0.0
melos:
  scripts:
    generate:
      description: Regenerate Pigeon code (Dart + Kotlin + Swift)
      run: cd fl_place_autocomplete_platform_interface && dart run pigeon --input pigeons/messages.dart
    analyze:
      run: melos exec -- flutter analyze
    test:
      description: Run tests in every package that has a test dir
      run: melos exec --dir-exists=test -- flutter test
    format:
      run: dart format .
```

- [ ] **Step 4: Add `resolution: workspace` to each package pubspec** (under `environment:`), set `environment.sdk: ^3.13.0` and `flutter: ">=3.44.0"` in each, and set `description`, `version: 0.1.0`, `repository` fields.

- [ ] **Step 5: Root `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  exclude: ["**/*.g.dart", "**/*.g.kt", "**/*.g.swift"]
linter:
  rules:
    - prefer_const_constructors
    - public_member_api_docs
```
Add `flutter_lints` dev dependency to each package, and `include: ../analysis_options.yaml` in each package's `analysis_options.yaml`.

- [ ] **Step 6: Verify and commit**

```bash
dart pub get && dart run melos --version && dart run melos run analyze
```
Expected: pub get succeeds; analyze passes (template code only).
Also write the MIT `LICENSE` and a `.gitignore` (Flutter + `.dart_tool`, `build/`, `.idea`, `*.iml`, `.DS_Store`, `example/lib/keys.dart`).

```bash
git add -A && git commit -m "chore: scaffold melos workspace and five packages"
```

---

### Task 2: Platform-interface geometry, options, prediction models

**Files:**
- Create: `fl_place_autocomplete_platform_interface/lib/src/models/lat_lng.dart`, `prediction_options.dart`, `place_prediction.dart`
- Test: `fl_place_autocomplete_platform_interface/test/models_test.dart`

**Interfaces:**
- Produces:
  - `LatLng(double latitude, double longitude)`, `LatLngBounds({required LatLng southwest, required LatLng northeast})`
  - `sealed class PlaceArea`; `CircularArea({required LatLng center, required double radiusMeters})`; `RectangularArea(LatLngBounds bounds)`
  - `PredictionOptions({PlaceArea? locationBias, LatLngBounds? locationRestriction, LatLng? origin, List<String> includedPrimaryTypes = const [], List<String> includedRegionCodes = const [], String? languageCode, String? regionCode, int? inputOffset})` (validating, non-const)
  - `MatchedRange(int start, int end)`; `PlacePrediction({placeId, fullText, primaryText, secondaryText, matchedRanges, types, distanceMeters})` with `List<MatchedRange> matchesWithin(int length)`

- [ ] **Step 1: Write the failing tests** (`test/models_test.dart`)

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PredictionOptions validation', () {
    test('rejects more than 5 primary types', () {
      expect(() => PredictionOptions(includedPrimaryTypes: List.filled(6, 'cafe')), throwsArgumentError);
    });
    test('rejects more than 15 region codes', () {
      expect(() => PredictionOptions(includedRegionCodes: List.filled(16, 'us')), throwsArgumentError);
    });
    test('rejects bias and restriction together', () {
      expect(
        () => PredictionOptions(
          locationBias: const CircularArea(center: LatLng(1, 1), radiusMeters: 100),
          locationRestriction: const LatLngBounds(southwest: LatLng(0, 0), northeast: LatLng(1, 1)),
        ),
        throwsArgumentError,
      );
    });
    test('rejects circle radius outside (0, 50000]', () {
      expect(() => PredictionOptions(locationBias: const CircularArea(center: LatLng(1, 1), radiusMeters: 0)), throwsArgumentError);
      expect(() => PredictionOptions(locationBias: const CircularArea(center: LatLng(1, 1), radiusMeters: 50001)), throwsArgumentError);
    });
    test('lower-cases region codes and rejects negative offset', () {
      expect(PredictionOptions(includedRegionCodes: ['US']).includedRegionCodes, ['us']);
      expect(() => PredictionOptions(inputOffset: -1), throwsArgumentError);
    });
  });

  group('PlacePrediction.matchesWithin', () {
    const p = PlacePrediction(
      placeId: 'id', fullText: 'Pizza Hut, NY', primaryText: 'Pizza Hut', secondaryText: 'NY',
      matchedRanges: [MatchedRange(0, 5), MatchedRange(7, 12), MatchedRange(-3, 2), MatchedRange(4, 4), MatchedRange(20, 30)],
      types: [],
    );
    test('clamps to length and drops empty or invalid ranges', () {
      final r = p.matchesWithin(9);
      expect(r.map((e) => (e.start, e.end)), [(0, 5), (7, 9), (0, 2)]);
    });
    test('handles empty primary text', () {
      expect(p.matchesWithin(0), isEmpty);
    });
    test('offsets are UTF-16 code units (emoji occupies 2)', () {
      const e = PlacePrediction(placeId: 'x', fullText: '🍕 Pizza', primaryText: '🍕 Pizza', secondaryText: '', matchedRanges: [MatchedRange(3, 8)], types: []);
      expect('🍕 Pizza'.substring(3, 8), 'Pizza');
      expect(e.matchesWithin('🍕 Pizza'.length).single.end, 8);
    });
  });
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `cd fl_place_autocomplete_platform_interface && flutter test test/models_test.dart`
Expected: FAIL (compile error: types not defined).

- [ ] **Step 3: Implement** `lat_lng.dart`

```dart
import 'package:meta/meta.dart';

/// A geographic coordinate.
@immutable
class LatLng {
  /// Creates a coordinate.
  const LatLng(this.latitude, this.longitude);

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  @override
  bool operator ==(Object other) => other is LatLng && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

/// A rectangle defined by its south-west and north-east corners.
@immutable
class LatLngBounds {
  /// Creates bounds.
  const LatLngBounds({required this.southwest, required this.northeast});

  /// South-west corner.
  final LatLng southwest;

  /// North-east corner.
  final LatLng northeast;

  @override
  bool operator ==(Object other) => other is LatLngBounds && other.southwest == southwest && other.northeast == northeast;

  @override
  int get hashCode => Object.hash(southwest, northeast);
}

/// An area used to bias autocomplete results.
@immutable
sealed class PlaceArea {
  /// Base constructor.
  const PlaceArea();
}

/// A circular bias area.
final class CircularArea extends PlaceArea {
  /// Creates a circle; [radiusMeters] must be in (0, 50000].
  const CircularArea({required this.center, required this.radiusMeters});

  /// Circle center.
  final LatLng center;

  /// Radius in meters.
  final double radiusMeters;
}

/// A rectangular bias area.
final class RectangularArea extends PlaceArea {
  /// Creates a rectangle.
  const RectangularArea(this.bounds);

  /// The rectangle.
  final LatLngBounds bounds;
}
```
Add `meta` to the package's dependencies.

`prediction_options.dart`:

```dart
import 'package:meta/meta.dart';
import 'lat_lng.dart';

/// Options for an autocomplete request.
@immutable
class PredictionOptions {
  /// Creates validated options. Throws [ArgumentError] on invalid input.
  PredictionOptions({
    this.locationBias,
    this.locationRestriction,
    this.origin,
    List<String> includedPrimaryTypes = const [],
    List<String> includedRegionCodes = const [],
    this.languageCode,
    this.regionCode,
    this.inputOffset,
  })  : includedPrimaryTypes = List.unmodifiable(includedPrimaryTypes),
        includedRegionCodes = List.unmodifiable(includedRegionCodes.map((c) => c.toLowerCase())) {
    if (includedPrimaryTypes.length > 5) {
      throw ArgumentError.value(includedPrimaryTypes.length, 'includedPrimaryTypes', 'at most 5 types are allowed');
    }
    if (includedRegionCodes.length > 15) {
      throw ArgumentError.value(includedRegionCodes.length, 'includedRegionCodes', 'at most 15 region codes are allowed');
    }
    if (locationBias != null && locationRestriction != null) {
      throw ArgumentError('locationBias and locationRestriction are mutually exclusive');
    }
    final bias = locationBias;
    if (bias is CircularArea && !(bias.radiusMeters > 0 && bias.radiusMeters <= 50000)) {
      throw ArgumentError.value(bias.radiusMeters, 'locationBias.radiusMeters', 'must be in (0, 50000]');
    }
    if (inputOffset != null && inputOffset! < 0) {
      throw ArgumentError.value(inputOffset, 'inputOffset', 'must be >= 0');
    }
  }

  /// Soft preference for results near an area.
  final PlaceArea? locationBias;

  /// Hard restriction to a rectangle.
  final LatLngBounds? locationRestriction;

  /// Point used to compute `distanceMeters`.
  final LatLng? origin;

  /// Primary place types to include (max 5).
  final List<String> includedPrimaryTypes;

  /// Lower-case two-letter region codes (max 15).
  final List<String> includedRegionCodes;

  /// BCP-47 language code for results.
  final String? languageCode;

  /// Region code for formatting.
  final String? regionCode;

  /// Cursor position in the input.
  final int? inputOffset;
}
```

`place_prediction.dart`:

```dart
import 'package:meta/meta.dart';

/// A half-open `[start, end)` range of UTF-16 code units.
@immutable
class MatchedRange {
  /// Creates a range.
  const MatchedRange(this.start, this.end);

  /// Inclusive start.
  final int start;

  /// Exclusive end.
  final int end;
}

/// An autocomplete prediction.
@immutable
class PlacePrediction {
  /// Creates a prediction.
  const PlacePrediction({
    required this.placeId,
    required this.fullText,
    required this.primaryText,
    required this.secondaryText,
    required this.matchedRanges,
    required this.types,
    this.distanceMeters,
  });

  /// Place ID.
  final String placeId;

  /// Full text, e.g. "Pizza Hut, New York".
  final String fullText;

  /// Main text.
  final String primaryText;

  /// Secondary text, possibly empty.
  final String secondaryText;

  /// Matched ranges relative to [fullText].
  final List<MatchedRange> matchedRanges;

  /// Place types.
  final List<String> types;

  /// Distance from the request origin, if one was supplied.
  final int? distanceMeters;

  /// Matched ranges clamped to `[0, length)`, dropping empty or invalid ones.
  /// Use with `primaryText.length` to highlight the primary text safely.
  List<MatchedRange> matchesWithin(int length) {
    final out = <MatchedRange>[];
    for (final r in matchedRanges) {
      final s = r.start < 0 ? 0 : r.start;
      final e = r.end > length ? length : r.end;
      if (s < e && s < length) out.add(MatchedRange(s, e));
    }
    return out;
  }
}
```

Create the barrel `lib/fl_place_autocomplete_platform_interface.dart` exporting `src/models/*.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/models_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(platform_interface): geometry, options, prediction models"
```

---

### Task 3: PlaceField and Place models

**Files:**
- Create: `lib/src/models/place_field.dart`, `place.dart`, `photo.dart`
- Test: `test/place_test.dart`

**Interfaces:**
- Produces:
  - `enum PlaceField { id, displayName, formattedAddress, shortFormattedAddress, location, viewport, addressComponents, types, primaryType, primaryTypeDisplayName, rating, userRatingCount, priceLevel, nationalPhoneNumber, internationalPhoneNumber, websiteUri, googleMapsUri, utcOffsetMinutes, businessStatus, editorialSummary, regularOpeningHours, photos, reviews }` with `String get apiName` (same as `name`)
  - `enum PriceLevel { free, inexpensive, moderate, expensive, veryExpensive }`, `enum BusinessStatus { operational, closedTemporarily, closedPermanently }`
  - `AddressComponent({longText, shortText, types})`, `TimePoint({day, hour, minute})` (day 0 = Sunday), `OpeningPeriod({open, close})`, `OpeningHours({weekdayDescriptions, periods})`, `AuthorAttribution({displayName, uri, photoUri})`, `PlacePhotoRef({id, widthPx, heightPx, authorAttributions})`, `PlaceReview({authorAttribution, rating, text, relativePublishTimeDescription, publishTime})`
  - `Place({...all fields nullable named...})`
  - `PhotoData({Uint8List? bytes, String? uri})`

- [ ] **Step 1: Failing test** (`test/place_test.dart`)

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlaceField.apiName equals enum name for every field', () {
    for (final f in PlaceField.values) {
      expect(f.apiName, f.name);
    }
    expect(PlaceField.values.length, 23);
  });

  test('Place with no data is valid and all fields are null', () {
    const p = Place();
    expect(p.location, isNull);
    expect(p.photos, isNull);
    expect(p.displayName, isNull);
  });

  test('Place exposes location as LatLng', () {
    const p = Place(location: LatLng(1.5, 2.5));
    expect(p.location!.latitude, 1.5);
    expect(p.location!.longitude, 2.5);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/place_test.dart` → FAIL (undefined).

- [ ] **Step 3: Implement.** `place_field.dart`:

```dart
/// Fields that can be requested from `fetchPlace`.
enum PlaceField {
  /// Place ID.
  id,
  /// Display name.
  displayName,
  /// Formatted address.
  formattedAddress,
  /// Short formatted address.
  shortFormattedAddress,
  /// Coordinates.
  location,
  /// Viewport bounds.
  viewport,
  /// Address components.
  addressComponents,
  /// Place types.
  types,
  /// Primary type.
  primaryType,
  /// Primary type display name.
  primaryTypeDisplayName,
  /// Average rating.
  rating,
  /// Number of ratings.
  userRatingCount,
  /// Price level.
  priceLevel,
  /// National phone number.
  nationalPhoneNumber,
  /// International phone number.
  internationalPhoneNumber,
  /// Website.
  websiteUri,
  /// Google Maps URL.
  googleMapsUri,
  /// UTC offset in minutes.
  utcOffsetMinutes,
  /// Business status.
  businessStatus,
  /// Editorial summary.
  editorialSummary,
  /// Regular opening hours.
  regularOpeningHours,
  /// Photo references.
  photos,
  /// Reviews.
  reviews;

  /// Name used by the native SDKs and the JS API (camelCase).
  String get apiName => name;
}
```

`photo.dart`:

```dart
import 'dart:typed_data';
import 'package:meta/meta.dart';

/// Attribution for a photo or review author.
@immutable
class AuthorAttribution {
  /// Creates an attribution.
  const AuthorAttribution({this.displayName, this.uri, this.photoUri});

  /// Author name.
  final String? displayName;

  /// Author profile URI.
  final String? uri;

  /// Author photo URI.
  final String? photoUri;
}

/// Reference to a photo; pass to `fetchPhoto`.
@immutable
class PlacePhotoRef {
  /// Creates a reference.
  const PlacePhotoRef({required this.id, this.widthPx, this.heightPx, this.authorAttributions = const []});

  /// Opaque ID owned by the platform implementation.
  final String id;

  /// Width in pixels.
  final int? widthPx;

  /// Height in pixels.
  final int? heightPx;

  /// Required attributions to display with the photo.
  final List<AuthorAttribution> authorAttributions;
}

/// Photo content: bytes or a URI, depending on the platform.
@immutable
class PhotoData {
  /// Creates photo data.
  const PhotoData({this.bytes, this.uri});

  /// Encoded image bytes.
  final Uint8List? bytes;

  /// Image URI.
  final String? uri;
}
```

`place.dart`: define `PriceLevel`, `BusinessStatus`, `AddressComponent`, `TimePoint`, `OpeningPeriod`, `OpeningHours`, `PlaceReview`, and `Place` as `@immutable` classes with `const` constructors, all-optional named params, and public final fields matching the interface list above (`Uri? websiteUri`, `Uri? googleMapsUri`, `PriceLevel? priceLevel`, `BusinessStatus? businessStatus`, `OpeningHours? regularOpeningHours`, `List<PlacePhotoRef>? photos`, `List<PlaceReview>? reviews`, `List<AddressComponent>? addressComponents`, `List<String>? types`, `LatLngBounds? viewport`, `LatLng? location`, `double? rating`, `int? userRatingCount`, `int? utcOffsetMinutes`, strings for the rest). Each public member gets a one-line `///` doc (the `public_member_api_docs` lint is on). Example for the two small ones:

```dart
/// A day/time within a week; [day] 0 is Sunday.
@immutable
class TimePoint {
  /// Creates a time point.
  const TimePoint({required this.day, required this.hour, required this.minute});
  /// Day of week, 0 = Sunday.
  final int day;
  /// Hour 0-23.
  final int hour;
  /// Minute 0-59.
  final int minute;
}

/// An opening period.
@immutable
class OpeningPeriod {
  /// Creates a period.
  const OpeningPeriod({this.open, this.close});
  /// Opening time.
  final TimePoint? open;
  /// Closing time.
  final TimePoint? close;
}
```
Export all from the barrel.

- [ ] **Step 4: Run** `flutter test test/place_test.dart` → PASS. Run `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(platform_interface): PlaceField, Place and photo models"
```

---

### Task 4: PlaceSession, exceptions, platform base class

**Files:**
- Create: `lib/src/place_session.dart`, `lib/src/exceptions.dart`, `lib/src/platform.dart`
- Test: `test/session_test.dart`

**Interfaces:**
- Produces:
  - `PlaceSession` with `static PlaceSession create()`, `PlaceSession.withId(String id)`, `String get id`, `bool get isEnded`, `void end()` (idempotent), `void ensureActive()` (throws `StateError` if ended)
  - `enum PlaceAutocompleteErrorCode { invalidApiKey, quotaExceeded, networkError, invalidRequest, notFound, sessionEnded, unknown }`; `PlaceAutocompleteException({required PlaceAutocompleteErrorCode code, String? message})` implements `Exception`
  - `abstract class FlPlaceAutocompletePlatform extends PlatformInterface` with `static instance` getter/setter and methods:
    - `Future<List<PlacePrediction>> findPredictions(String input, {String? sessionId, required PredictionOptions options})`
    - `Future<Place> fetchPlace(String placeId, {String? sessionId, required Set<PlaceField> fields, String? languageCode, String? regionCode})`
    - `Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight})`
    - `Future<void> disposeSession(String sessionId)`
    each throwing `UnimplementedError` by default.

- [ ] **Step 1: Failing test**

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create() yields unique 32-char hex ids', () {
    final ids = {for (var i = 0; i < 100; i++) PlaceSession.create().id};
    expect(ids.length, 100);
    expect(ids.every((id) => RegExp(r'^[0-9a-f]{32}$').hasMatch(id)), isTrue);
  });

  test('end() is idempotent and ensureActive throws StateError afterwards', () {
    final s = PlaceSession.withId('a');
    s.ensureActive();
    s.end();
    s.end();
    expect(s.isEnded, isTrue);
    expect(s.ensureActive, throwsStateError);
  });

  test('default platform methods throw UnimplementedError', () {
    expect(
      () => FlPlaceAutocompletePlatform.instance.findPredictions('x', options: PredictionOptions()),
      throwsUnimplementedError,
    );
  });
}
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement**

`place_session.dart`:

```dart
import 'dart:math';

/// A single-use autocomplete session. Created in Dart; native sides lazily
/// map [id] to their real session token.
class PlaceSession {
  /// Wraps an explicit [id] (useful in tests).
  PlaceSession.withId(this.id);

  /// Creates a session with a random 128-bit id.
  factory PlaceSession.create() {
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return PlaceSession.withId(id);
  }

  /// Opaque id shared with the platform implementation.
  final String id;
  bool _ended = false;

  /// Whether the session has ended (a place was fetched or it was cancelled).
  bool get isEnded => _ended;

  /// Marks the session ended. Safe to call repeatedly.
  void end() => _ended = true;

  /// Throws [StateError] if the session has ended.
  void ensureActive() {
    if (_ended) {
      throw StateError('PlaceSession $id has ended; create a new session with newSession().');
    }
  }
}
```

`exceptions.dart`:

```dart
/// Error codes shared by all platforms.
enum PlaceAutocompleteErrorCode {
  /// API key missing or rejected.
  invalidApiKey,
  /// Quota exceeded.
  quotaExceeded,
  /// Network failure.
  networkError,
  /// Malformed request.
  invalidRequest,
  /// Place not found.
  notFound,
  /// Session already ended.
  sessionEnded,
  /// Anything else.
  unknown,
}

/// Thrown for Places failures.
class PlaceAutocompleteException implements Exception {
  /// Creates an exception.
  const PlaceAutocompleteException({required this.code, this.message});

  /// Error code.
  final PlaceAutocompleteErrorCode code;

  /// Native message.
  final String? message;

  @override
  String toString() => 'PlaceAutocompleteException(${code.name}: $message)';
}
```

`platform.dart`:

```dart
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'models/lat_lng.dart';
import 'models/photo.dart';
import 'models/place.dart';
import 'models/place_field.dart';
import 'models/place_prediction.dart';
import 'models/prediction_options.dart';

/// Platform interface for fl_place_autocomplete.
abstract class FlPlaceAutocompletePlatform extends PlatformInterface {
  /// Constructs the platform.
  FlPlaceAutocompletePlatform() : super(token: _token);

  static final Object _token = Object();
  static FlPlaceAutocompletePlatform _instance = _Unimplemented();

  /// Current implementation.
  static FlPlaceAutocompletePlatform get instance => _instance;

  /// Registers an implementation.
  static set instance(FlPlaceAutocompletePlatform value) {
    PlatformInterface.verify(value, _token);
    _instance = value;
  }

  /// Fetches predictions. [sessionId] null means "no session".
  Future<List<PlacePrediction>> findPredictions(String input, {String? sessionId, required PredictionOptions options}) =>
      throw UnimplementedError('findPredictions() has not been implemented.');

  /// Fetches place details; ends the native session [sessionId] on success.
  Future<Place> fetchPlace(String placeId, {String? sessionId, required Set<PlaceField> fields, String? languageCode, String? regionCode}) =>
      throw UnimplementedError('fetchPlace() has not been implemented.');

  /// Fetches a photo.
  Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight}) =>
      throw UnimplementedError('fetchPhoto() has not been implemented.');

  /// Drops the native token for [sessionId].
  Future<void> disposeSession(String sessionId) =>
      throw UnimplementedError('disposeSession() has not been implemented.');
}

class _Unimplemented extends FlPlaceAutocompletePlatform {}
```
(Remove the unused `lat_lng.dart` import.) Add `plugin_platform_interface: ^2.1.8` to dependencies; export new files from the barrel.

- [ ] **Step 4: Run** `flutter test` → PASS; `flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(platform_interface): PlaceSession, exceptions, platform base class"
```

---

### Task 5: Pigeon schema, generated code, shared Dart implementation

**Files:**
- Create: `pigeons/messages.dart`, `lib/src/pigeon/mappers.dart`, `lib/src/pigeon/pigeon_platform.dart`
- Generated: `lib/src/pigeon/messages.g.dart`, Kotlin `Messages.g.kt` (Android), Swift `Messages.g.swift` (iOS)
- Test: `test/mappers_test.dart`, `test/pigeon_platform_test.dart`

**Interfaces:**
- Consumes: Task 2-4 types.
- Produces:
  - Generated `PlacesHostApi` (Dart class; Kotlin interface `PlacesHostApi`; Swift protocol `PlacesHostApi` with `PlacesHostApiSetup.setUp`), message classes (`...Msg`).
  - `PigeonPlacesPlatform extends FlPlaceAutocompletePlatform` with constructor `PigeonPlacesPlatform({PlacesHostApi? api})`.
  - `PlaceAutocompleteException mapPlatformException(PlatformException e)`; `PredictionOptions` → `OptionsMsg` (`optionsToMsg`), `predictionFromMsg`, `placeFromMsg`, `photoRefToMsg`.
  - Error codes crossing the channel are exactly `PlaceAutocompleteErrorCode.name` values.

- [ ] **Step 1: Add dev dependency and the schema.** In platform_interface `pubspec.yaml` add `dev_dependencies: pigeon: ^29.0.0`. Create `pigeons/messages.dart`:

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/pigeon/messages.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: '../fl_place_autocomplete_android/android/src/main/kotlin/com/mk7/fl_place_autocomplete_android/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.mk7.fl_place_autocomplete_android'),
  swiftOut: '../fl_place_autocomplete_ios/ios/fl_place_autocomplete_ios/Sources/fl_place_autocomplete_ios/Messages.g.swift',
  dartPackageName: 'fl_place_autocomplete_platform_interface',
))
class LatLngMsg {
  LatLngMsg({required this.latitude, required this.longitude});
  double latitude;
  double longitude;
}

class LatLngBoundsMsg {
  LatLngBoundsMsg({required this.southwest, required this.northeast});
  LatLngMsg southwest;
  LatLngMsg northeast;
}

/// Circle when [center] != null, rectangle when [bounds] != null.
class AreaMsg {
  AreaMsg({this.center, this.radiusMeters, this.bounds});
  LatLngMsg? center;
  double? radiusMeters;
  LatLngBoundsMsg? bounds;
}

class OptionsMsg {
  OptionsMsg({
    this.locationBias,
    this.locationRestriction,
    this.origin,
    required this.includedPrimaryTypes,
    required this.includedRegionCodes,
    this.languageCode,
    this.regionCode,
    this.inputOffset,
  });
  AreaMsg? locationBias;
  LatLngBoundsMsg? locationRestriction;
  LatLngMsg? origin;
  List<String> includedPrimaryTypes;
  List<String> includedRegionCodes;
  String? languageCode;
  String? regionCode;
  int? inputOffset;
}

class MatchedRangeMsg {
  MatchedRangeMsg({required this.start, required this.end});
  int start;
  int end;
}

class PredictionMsg {
  PredictionMsg({
    required this.placeId,
    required this.fullText,
    required this.primaryText,
    required this.secondaryText,
    required this.matchedRanges,
    required this.types,
    this.distanceMeters,
  });
  String placeId;
  String fullText;
  String primaryText;
  String secondaryText;
  List<MatchedRangeMsg> matchedRanges;
  List<String> types;
  int? distanceMeters;
}

class AddressComponentMsg {
  AddressComponentMsg({this.longText, this.shortText, required this.types});
  String? longText;
  String? shortText;
  List<String> types;
}

class TimePointMsg {
  TimePointMsg({required this.day, required this.hour, required this.minute});
  int day;
  int hour;
  int minute;
}

class OpeningPeriodMsg {
  OpeningPeriodMsg({this.open, this.close});
  TimePointMsg? open;
  TimePointMsg? close;
}

class OpeningHoursMsg {
  OpeningHoursMsg({required this.weekdayDescriptions, required this.periods});
  List<String> weekdayDescriptions;
  List<OpeningPeriodMsg> periods;
}

class AuthorAttributionMsg {
  AuthorAttributionMsg({this.displayName, this.uri, this.photoUri});
  String? displayName;
  String? uri;
  String? photoUri;
}

class PhotoRefMsg {
  PhotoRefMsg({required this.id, this.widthPx, this.heightPx, required this.authorAttributions});
  String id;
  int? widthPx;
  int? heightPx;
  List<AuthorAttributionMsg> authorAttributions;
}

class ReviewMsg {
  ReviewMsg({this.authorAttribution, this.rating, this.text, this.relativePublishTimeDescription, this.publishTime});
  AuthorAttributionMsg? authorAttribution;
  double? rating;
  String? text;
  String? relativePublishTimeDescription;
  String? publishTime;
}

/// All fields optional; only requested fields are populated.
/// priceLevel: free|inexpensive|moderate|expensive|veryExpensive.
/// businessStatus: operational|closedTemporarily|closedPermanently.
class PlaceMsg {
  PlaceMsg({
    this.id, this.displayName, this.formattedAddress, this.shortFormattedAddress,
    this.location, this.viewport, this.addressComponents, this.types, this.primaryType,
    this.primaryTypeDisplayName, this.rating, this.userRatingCount, this.priceLevel,
    this.nationalPhoneNumber, this.internationalPhoneNumber, this.websiteUri,
    this.googleMapsUri, this.utcOffsetMinutes, this.businessStatus, this.editorialSummary,
    this.regularOpeningHours, this.photos, this.reviews,
  });
  String? id;
  String? displayName;
  String? formattedAddress;
  String? shortFormattedAddress;
  LatLngMsg? location;
  LatLngBoundsMsg? viewport;
  List<AddressComponentMsg>? addressComponents;
  List<String>? types;
  String? primaryType;
  String? primaryTypeDisplayName;
  double? rating;
  int? userRatingCount;
  String? priceLevel;
  String? nationalPhoneNumber;
  String? internationalPhoneNumber;
  String? websiteUri;
  String? googleMapsUri;
  int? utcOffsetMinutes;
  String? businessStatus;
  String? editorialSummary;
  OpeningHoursMsg? regularOpeningHours;
  List<PhotoRefMsg>? photos;
  List<ReviewMsg>? reviews;
}

class PhotoDataMsg {
  PhotoDataMsg({this.bytes, this.uri});
  Uint8List? bytes;
  String? uri;
}

@HostApi()
abstract class PlacesHostApi {
  /// Validates the native key / SDK setup; throws FlutterError(invalidApiKey) if missing.
  @async
  void initialize();

  /// Drops the native session token for [sessionId], if any.
  void disposeSession(String sessionId);

  @async
  List<PredictionMsg> findPredictions(String input, String? sessionId, OptionsMsg options);

  @async
  PlaceMsg fetchPlace(String placeId, String? sessionId, List<String> fields, String? languageCode, String? regionCode);

  @async
  PhotoDataMsg fetchPhoto(PhotoRefMsg ref, int? maxWidth, int? maxHeight);
}
```

- [ ] **Step 2: Generate** (creates the Android/iOS directories first if missing)

```bash
mkdir -p fl_place_autocomplete_android/android/src/main/kotlin/com/mk7/fl_place_autocomplete_android \
         fl_place_autocomplete_ios/ios/fl_place_autocomplete_ios/Sources/fl_place_autocomplete_ios
cd fl_place_autocomplete_platform_interface && dart pub get && dart run pigeon --input pigeons/messages.dart
git -C .. status --short | grep '\.g\.'
```
Expected: three `Messages.g.*` files exist. Check the Pigeon docs if option names differ in the installed version; do not change message shapes.

- [ ] **Step 3: Failing tests.** `test/mappers_test.dart`:

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/mappers.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('optionsToMsg maps circle bias and lists', () {
    final msg = optionsToMsg(PredictionOptions(
      locationBias: const CircularArea(center: LatLng(1, 2), radiusMeters: 500),
      includedPrimaryTypes: ['cafe'],
      includedRegionCodes: ['us'],
      languageCode: 'en',
      inputOffset: 3,
    ));
    expect(msg.locationBias!.center!.latitude, 1);
    expect(msg.locationBias!.radiusMeters, 500);
    expect(msg.locationBias!.bounds, isNull);
    expect(msg.includedPrimaryTypes, ['cafe']);
    expect(msg.inputOffset, 3);
  });

  test('optionsToMsg maps rectangle bias and restriction', () {
    const b = LatLngBounds(southwest: LatLng(0, 0), northeast: LatLng(2, 2));
    expect(optionsToMsg(PredictionOptions(locationBias: const RectangularArea(b))).locationBias!.bounds!.northeast.latitude, 2);
    expect(optionsToMsg(PredictionOptions(locationRestriction: b)).locationRestriction!.southwest.longitude, 0);
  });

  test('predictionFromMsg maps ranges and distance', () {
    final p = predictionFromMsg(PredictionMsg(
      placeId: 'p', fullText: 'A, B', primaryText: 'A', secondaryText: 'B',
      matchedRanges: [MatchedRangeMsg(start: 0, end: 1)], types: ['x'], distanceMeters: 42));
    expect(p.matchedRanges.single.end, 1);
    expect(p.distanceMeters, 42);
  });

  test('placeFromMsg maps location, enums, uris, nested lists; unrequested stay null', () {
    final place = placeFromMsg(PlaceMsg(
      id: 'p', location: LatLngMsg(latitude: 9, longitude: 8), priceLevel: 'veryExpensive',
      businessStatus: 'closedTemporarily', websiteUri: 'https://x.dev',
      regularOpeningHours: OpeningHoursMsg(weekdayDescriptions: ['Mon'], periods: [
        OpeningPeriodMsg(open: TimePointMsg(day: 1, hour: 9, minute: 0))]),
      photos: [PhotoRefMsg(id: 'ph', authorAttributions: [AuthorAttributionMsg(displayName: 'N')])],
    ));
    expect(place.location, const LatLng(9, 8));
    expect(place.priceLevel, PriceLevel.veryExpensive);
    expect(place.businessStatus, BusinessStatus.closedTemporarily);
    expect(place.websiteUri, Uri.parse('https://x.dev'));
    expect(place.regularOpeningHours!.periods.single.open!.hour, 9);
    expect(place.photos!.single.authorAttributions.single.displayName, 'N');
    expect(place.displayName, isNull);
    expect(place.reviews, isNull);
  });

  test('mapPlatformException maps known codes and falls back to unknown', () {
    expect(mapPlatformException(PlatformException(code: 'quotaExceeded', message: 'm')).code, PlaceAutocompleteErrorCode.quotaExceeded);
    expect(mapPlatformException(PlatformException(code: 'weird')).code, PlaceAutocompleteErrorCode.unknown);
  });
}
```

`test/pigeon_platform_test.dart`:

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/messages.g.dart';
import 'package:fl_place_autocomplete_platform_interface/src/pigeon/pigeon_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends PlacesHostApi {
  Object? error;
  String? lastSession;
  List<String>? lastFields;
  @override
  Future<List<PredictionMsg>> findPredictions(String input, String? sessionId, OptionsMsg options) async {
    if (error != null) throw error!;
    lastSession = sessionId;
    return [PredictionMsg(placeId: 'p', fullText: 'f', primaryText: 'f', secondaryText: '', matchedRanges: [], types: [])];
  }
  @override
  Future<PlaceMsg> fetchPlace(String placeId, String? sessionId, List<String> fields, String? languageCode, String? regionCode) async {
    lastSession = sessionId;
    lastFields = fields;
    return PlaceMsg(id: placeId);
  }
  @override
  Future<void> disposeSession(String sessionId) async => lastSession = 'disposed:$sessionId';
  @override
  Future<void> initialize() async {}
  @override
  Future<PhotoDataMsg> fetchPhoto(PhotoRefMsg ref, int? maxWidth, int? maxHeight) async => PhotoDataMsg(uri: 'u');
}

void main() {
  test('passes session id and field api names through', () async {
    final api = _Api();
    final platform = PigeonPlacesPlatform(api: api);
    await platform.findPredictions('pi', sessionId: 's1', options: PredictionOptions());
    expect(api.lastSession, 's1');
    final p = await platform.fetchPlace('p', sessionId: 's1', fields: {PlaceField.location, PlaceField.displayName});
    expect(p.id, 'p');
    expect(api.lastFields!.toSet(), {'location', 'displayName'});
    await platform.disposeSession('s1');
    expect(api.lastSession, 'disposed:s1');
  });

  test('PlatformException becomes PlaceAutocompleteException', () async {
    final api = _Api()..error = PlatformException(code: 'invalidApiKey', message: 'no key');
    expect(
      PigeonPlacesPlatform(api: api).findPredictions('x', options: PredictionOptions()),
      throwsA(isA<PlaceAutocompleteException>().having((e) => e.code, 'code', PlaceAutocompleteErrorCode.invalidApiKey)),
    );
  });
}
```

- [ ] **Step 4: Run** `flutter test` → FAIL (mappers/platform missing).

- [ ] **Step 5: Implement `mappers.dart`**

```dart
import 'package:flutter/services.dart';

import '../exceptions.dart';
import '../models/lat_lng.dart';
import '../models/photo.dart';
import '../models/place.dart';
import '../models/place_prediction.dart';
import '../models/prediction_options.dart';
import 'messages.g.dart';

LatLngMsg _ll(LatLng v) => LatLngMsg(latitude: v.latitude, longitude: v.longitude);
LatLngBoundsMsg _bounds(LatLngBounds b) => LatLngBoundsMsg(southwest: _ll(b.southwest), northeast: _ll(b.northeast));
LatLng _fromLl(LatLngMsg m) => LatLng(m.latitude, m.longitude);
LatLngBounds _fromBounds(LatLngBoundsMsg m) => LatLngBounds(southwest: _fromLl(m.southwest), northeast: _fromLl(m.northeast));

/// Converts options to their Pigeon message.
OptionsMsg optionsToMsg(PredictionOptions o) {
  AreaMsg? bias;
  switch (o.locationBias) {
    case CircularArea(:final center, :final radiusMeters):
      bias = AreaMsg(center: _ll(center), radiusMeters: radiusMeters);
    case RectangularArea(:final bounds):
      bias = AreaMsg(bounds: _bounds(bounds));
    case null:
      break;
  }
  return OptionsMsg(
    locationBias: bias,
    locationRestriction: o.locationRestriction == null ? null : _bounds(o.locationRestriction!),
    origin: o.origin == null ? null : _ll(o.origin!),
    includedPrimaryTypes: o.includedPrimaryTypes,
    includedRegionCodes: o.includedRegionCodes,
    languageCode: o.languageCode,
    regionCode: o.regionCode,
    inputOffset: o.inputOffset,
  );
}

/// Converts a prediction message.
PlacePrediction predictionFromMsg(PredictionMsg m) => PlacePrediction(
      placeId: m.placeId,
      fullText: m.fullText,
      primaryText: m.primaryText,
      secondaryText: m.secondaryText,
      matchedRanges: [for (final r in m.matchedRanges) MatchedRange(r.start, r.end)],
      types: m.types,
      distanceMeters: m.distanceMeters,
    );

AuthorAttribution _author(AuthorAttributionMsg m) => AuthorAttribution(displayName: m.displayName, uri: m.uri, photoUri: m.photoUri);
TimePoint _tp(TimePointMsg m) => TimePoint(day: m.day, hour: m.hour, minute: m.minute);

/// Converts a place message.
Place placeFromMsg(PlaceMsg m) => Place(
      id: m.id,
      displayName: m.displayName,
      formattedAddress: m.formattedAddress,
      shortFormattedAddress: m.shortFormattedAddress,
      location: m.location == null ? null : _fromLl(m.location!),
      viewport: m.viewport == null ? null : _fromBounds(m.viewport!),
      addressComponents: m.addressComponents
          ?.map((c) => AddressComponent(longText: c.longText, shortText: c.shortText, types: c.types))
          .toList(),
      types: m.types,
      primaryType: m.primaryType,
      primaryTypeDisplayName: m.primaryTypeDisplayName,
      rating: m.rating,
      userRatingCount: m.userRatingCount,
      priceLevel: PriceLevel.values.asNameMap()[m.priceLevel],
      nationalPhoneNumber: m.nationalPhoneNumber,
      internationalPhoneNumber: m.internationalPhoneNumber,
      websiteUri: m.websiteUri == null ? null : Uri.tryParse(m.websiteUri!),
      googleMapsUri: m.googleMapsUri == null ? null : Uri.tryParse(m.googleMapsUri!),
      utcOffsetMinutes: m.utcOffsetMinutes,
      businessStatus: BusinessStatus.values.asNameMap()[m.businessStatus],
      editorialSummary: m.editorialSummary,
      regularOpeningHours: m.regularOpeningHours == null
          ? null
          : OpeningHours(
              weekdayDescriptions: m.regularOpeningHours!.weekdayDescriptions,
              periods: [
                for (final p in m.regularOpeningHours!.periods)
                  OpeningPeriod(open: p.open == null ? null : _tp(p.open!), close: p.close == null ? null : _tp(p.close!)),
              ],
            ),
      photos: m.photos
          ?.map((p) => PlacePhotoRef(id: p.id, widthPx: p.widthPx, heightPx: p.heightPx, authorAttributions: p.authorAttributions.map(_author).toList()))
          .toList(),
      reviews: m.reviews
          ?.map((r) => PlaceReview(
                authorAttribution: r.authorAttribution == null ? null : _author(r.authorAttribution!),
                rating: r.rating,
                text: r.text,
                relativePublishTimeDescription: r.relativePublishTimeDescription,
                publishTime: r.publishTime,
              ))
          .toList(),
    );

/// Converts a photo reference to its message.
PhotoRefMsg photoRefToMsg(PlacePhotoRef r) => PhotoRefMsg(
      id: r.id,
      widthPx: r.widthPx,
      heightPx: r.heightPx,
      authorAttributions: [
        for (final a in r.authorAttributions) AuthorAttributionMsg(displayName: a.displayName, uri: a.uri, photoUri: a.photoUri),
      ],
    );

/// Maps a native error to a [PlaceAutocompleteException].
PlaceAutocompleteException mapPlatformException(PlatformException e) => PlaceAutocompleteException(
      code: PlaceAutocompleteErrorCode.values.asNameMap()[e.code] ?? PlaceAutocompleteErrorCode.unknown,
      message: e.message,
    );
```
(`PlaceReview` / `PlaceAutocompleteException` etc. come from `place.dart`/`exceptions.dart`; ensure `PlaceReview` is defined in `place.dart` in Task 3 with the named params used above.)

`pigeon_platform.dart`:

```dart
import 'package:flutter/services.dart';

import '../models/photo.dart';
import '../models/place.dart';
import '../models/place_field.dart';
import '../models/place_prediction.dart';
import '../models/prediction_options.dart';
import '../platform.dart';
import 'mappers.dart';
import 'messages.g.dart';

/// Shared implementation used by the Android and iOS packages.
class PigeonPlacesPlatform extends FlPlaceAutocompletePlatform {
  /// Creates the platform; [api] is injectable for tests.
  PigeonPlacesPlatform({PlacesHostApi? api}) : _api = api ?? PlacesHostApi();

  final PlacesHostApi _api;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      throw mapPlatformException(e);
    }
  }

  @override
  Future<List<PlacePrediction>> findPredictions(String input, {String? sessionId, required PredictionOptions options}) =>
      _guard(() async => (await _api.findPredictions(input, sessionId, optionsToMsg(options))).map(predictionFromMsg).toList());

  @override
  Future<Place> fetchPlace(String placeId, {String? sessionId, required Set<PlaceField> fields, String? languageCode, String? regionCode}) =>
      _guard(() async => placeFromMsg(await _api.fetchPlace(placeId, sessionId, fields.map((f) => f.apiName).toList(), languageCode, regionCode)));

  @override
  Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight}) => _guard(() async {
        final m = await _api.fetchPhoto(photoRefToMsg(ref), maxWidth, maxHeight);
        return PhotoData(bytes: m.bytes, uri: m.uri);
      });

  @override
  Future<void> disposeSession(String sessionId) => _guard(() => _api.disposeSession(sessionId));
}
```
Export `PigeonPlacesPlatform` and `mapPlatformException` from the barrel (`export 'src/pigeon/pigeon_platform.dart' show PigeonPlacesPlatform;`).

- [ ] **Step 6: Run** `flutter test` → PASS; `flutter analyze` clean.

- [ ] **Step 7: Commit** (include generated files)

```bash
git add -A && git commit -m "feat(platform_interface): Pigeon schema, mappers and shared host-API platform"
```

---

### Task 6: App-facing API (`FlPlaceAutocomplete`) with session rules

**Files:**
- Create: `fl_place_autocomplete/lib/src/api.dart`, `lib/fl_place_autocomplete.dart`, `test/support/fake_platform.dart`
- Test: `fl_place_autocomplete/test/api_test.dart`
- Modify: `fl_place_autocomplete/pubspec.yaml`

**Interfaces:**
- Consumes: platform interface types.
- Produces:
  - `FlPlaceAutocomplete({FlPlaceAutocompletePlatform? platform})`, `static final FlPlaceAutocomplete instance`
  - `PlaceSession newSession()`
  - `Future<List<PlacePrediction>> findPredictions(String input, {PlaceSession? session, PredictionOptions? options})`: returns `[]` without a platform call when `input.trim().isEmpty`; calls `session.ensureActive()`.
  - `Future<Place> fetchPlace(String placeId, {PlaceSession? session, required Set<PlaceField> fields, String? languageCode, String? regionCode})`: throws `ArgumentError` if `fields` empty, `StateError` if session ended; ends session only after success.
  - `Future<void> cancelSession(PlaceSession session)`: ends it and calls `disposeSession` once (no-op if already ended).
  - `Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight})`
  - `FakePlatform` test helper (records calls, configurable responses).

- [ ] **Step 1: Pubspec.** Dependencies: `flutter`, `fl_place_autocomplete_platform_interface: ^0.1.0` (workspace resolves locally), `plugin_platform_interface`. Plugin section:

```yaml
flutter:
  plugin:
    platforms:
      android:
        default_package: fl_place_autocomplete_android
      ios:
        default_package: fl_place_autocomplete_ios
      web:
        default_package: fl_place_autocomplete_web
```
and `dependencies` on the three implementation packages (`fl_place_autocomplete_android: ^0.1.0`, etc.).

- [ ] **Step 2: Fake platform** (`test/support/fake_platform.dart`)

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

typedef FindCall = ({String input, String? sessionId, PredictionOptions options});
typedef FetchCall = ({String placeId, String? sessionId, Set<PlaceField> fields});

class FakePlatform extends FlPlaceAutocompletePlatform with MockPlatformInterfaceMixin {
  final findCalls = <FindCall>[];
  final fetchCalls = <FetchCall>[];
  final disposed = <String>[];

  Future<List<PlacePrediction>> Function(String input)? onFind;
  Future<Place> Function(String placeId)? onFetch;

  int get totalCalls => findCalls.length + fetchCalls.length + disposed.length;

  @override
  Future<List<PlacePrediction>> findPredictions(String input, {String? sessionId, required PredictionOptions options}) {
    findCalls.add((input: input, sessionId: sessionId, options: options));
    return onFind?.call(input) ?? Future.value([prediction('$input-1')]);
  }

  @override
  Future<Place> fetchPlace(String placeId, {String? sessionId, required Set<PlaceField> fields, String? languageCode, String? regionCode}) {
    fetchCalls.add((placeId: placeId, sessionId: sessionId, fields: fields));
    return onFetch?.call(placeId) ?? Future.value(Place(id: placeId, location: const LatLng(1, 2), displayName: 'Name $placeId'));
  }

  @override
  Future<void> disposeSession(String sessionId) async => disposed.add(sessionId);
}

PlacePrediction prediction(String id, {String? text}) => PlacePrediction(
      placeId: id, fullText: text ?? 'Text $id', primaryText: text ?? 'Text $id', secondaryText: 'Sub', matchedRanges: const [MatchedRange(0, 2)], types: const []);
```

- [ ] **Step 3: Failing tests** (`test/api_test.dart`)

```dart
import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_platform.dart';

void main() {
  late FakePlatform platform;
  late FlPlaceAutocomplete api;
  setUp(() {
    platform = FakePlatform();
    api = FlPlaceAutocomplete(platform: platform);
  });

  test('blank input returns empty without a platform call', () async {
    expect(await api.findPredictions('   '), isEmpty);
    expect(platform.totalCalls, 0);
  });

  test('same session id is used for every request in a session', () async {
    final s = api.newSession();
    await api.findPredictions('pi', session: s);
    await api.findPredictions('piz', session: s);
    expect(platform.findCalls.map((c) => c.sessionId).toSet(), {s.id});
  });

  test('no session means no session id is sent', () async {
    await api.findPredictions('pi');
    expect(platform.findCalls.single.sessionId, isNull);
  });

  test('fetchPlace ends the session; reuse throws StateError', () async {
    final s = api.newSession();
    await api.findPredictions('pi', session: s);
    final place = await api.fetchPlace('p1', session: s, fields: {PlaceField.location});
    expect(place.location, const LatLng(1, 2));
    expect(platform.fetchCalls.single.sessionId, s.id);
    expect(s.isEnded, isTrue);
    expect(() => api.findPredictions('x', session: s), throwsStateError);
    expect(() => api.fetchPlace('p1', session: s, fields: {PlaceField.id}), throwsStateError);
  });

  test('fetchPlace failure leaves the session active so it can be retried', () async {
    final s = api.newSession();
    platform.onFetch = (_) => Future.error(const PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.networkError));
    await expectLater(api.fetchPlace('p', session: s, fields: {PlaceField.id}), throwsA(isA<PlaceAutocompleteException>()));
    expect(s.isEnded, isFalse);
    platform.onFetch = null;
    await api.fetchPlace('p', session: s, fields: {PlaceField.id});
    expect(s.isEnded, isTrue);
  });

  test('empty fields is rejected', () {
    expect(() => api.fetchPlace('p', fields: {}), throwsArgumentError);
  });

  test('cancelSession ends and disposes once', () async {
    final s = api.newSession();
    await api.cancelSession(s);
    await api.cancelSession(s);
    expect(platform.disposed, [s.id]);
    expect(s.isEnded, isTrue);
  });
}
```

- [ ] **Step 4: Run** `cd fl_place_autocomplete && flutter test test/api_test.dart` → FAIL.

- [ ] **Step 5: Implement `api.dart`**

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';

/// Headless Places autocomplete API.
class FlPlaceAutocomplete {
  /// Creates an API; [platform] defaults to the registered implementation.
  FlPlaceAutocomplete({FlPlaceAutocompletePlatform? platform}) : _platform = platform;

  /// Shared instance.
  static final FlPlaceAutocomplete instance = FlPlaceAutocomplete();

  final FlPlaceAutocompletePlatform? _platform;
  FlPlaceAutocompletePlatform get _p => _platform ?? FlPlaceAutocompletePlatform.instance;

  /// Starts a new single-use session.
  PlaceSession newSession() => PlaceSession.create();

  /// Returns predictions for [input]. Blank input returns an empty list.
  Future<List<PlacePrediction>> findPredictions(String input, {PlaceSession? session, PredictionOptions? options}) async {
    session?.ensureActive();
    if (input.trim().isEmpty) return const [];
    return _p.findPredictions(input, sessionId: session?.id, options: options ?? PredictionOptions());
  }

  /// Fetches place details; ends [session] when the call succeeds.
  Future<Place> fetchPlace(String placeId, {PlaceSession? session, required Set<PlaceField> fields, String? languageCode, String? regionCode}) async {
    if (fields.isEmpty) throw ArgumentError.value(fields, 'fields', 'must not be empty');
    session?.ensureActive();
    final place = await _p.fetchPlace(placeId, sessionId: session?.id, fields: fields, languageCode: languageCode, regionCode: regionCode);
    session?.end();
    return place;
  }

  /// Abandons [session], releasing its native token.
  Future<void> cancelSession(PlaceSession session) async {
    if (session.isEnded) return;
    session.end();
    await _p.disposeSession(session.id);
  }

  /// Fetches a photo for a [PlacePhotoRef].
  Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight}) =>
      _p.fetchPhoto(ref, maxWidth: maxWidth, maxHeight: maxHeight);
}
```
`lib/fl_place_autocomplete.dart`:

```dart
export 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart'
    hide FlPlaceAutocompletePlatform, PigeonPlacesPlatform;
export 'src/api.dart';
```
(Widget exports are added in Tasks 7–8.)

- [ ] **Step 6: Run** `flutter test test/api_test.dart` → PASS.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: app-facing API with session lifecycle rules"
```

---

### Task 7: PlaceAutocompleteController (all widget behaviour)

**Files:**
- Create: `fl_place_autocomplete/lib/src/widget/controller.dart`
- Test: `fl_place_autocomplete/test/controller_test.dart`

**Interfaces:**
- Consumes: `FlPlaceAutocomplete`, `FakePlatform`.
- Produces:
  - `enum PlaceAutocompleteStatus { idle, loading, results, empty, error }`
  - `class PlaceAutocompleteConfig({required FlPlaceAutocomplete api, required PredictionOptions options, required Set<PlaceField> fields, Duration debounce = const Duration(milliseconds: 300), int minChars = 2, bool fetchDetailsOnSelect = true, void Function(PlacePrediction)? onPredictionSelected, void Function(Place)? onPlaceSelected, void Function(PlaceAutocompleteException)? onError})`
  - `class PlaceAutocompleteController extends ChangeNotifier`:
    - `PlaceAutocompleteController({String text = ''})`; `final TextEditingController textController`
    - getters: `status`, `predictions`, `error`, `selectedPlace`, `highlightedIndex`, `overlayOpen`, `session` (current `PlaceSession?`)
    - `void attach(PlaceAutocompleteConfig config)`
    - `void setText(String)`, `void setPlace(Place place, {String? text})`, `void clear()`, `Future<void> select(PlacePrediction)`, `void retry()`, `void moveHighlight(int delta)`, `Future<void> selectHighlighted()`, `void dismiss()`, `void onFocusLost()`, `PlaceSession? takeSession()`
  - `const Set<PlaceField> defaultPlaceFields`

- [ ] **Step 1: Failing tests** (`test/controller_test.dart`). Uses `fakeAsync`-free `flutter_test` async with real small debounce (`Duration(milliseconds: 10)`) and `await Future.delayed`; to keep deterministic use `FakeAsync` via `fakeAsync` from `package:fake_async` (add dev dependency `fake_async`).

```dart
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:fl_place_autocomplete/src/widget/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_platform.dart';

const debounce = Duration(milliseconds: 300);

({FakePlatform platform, PlaceAutocompleteController c, List<Place> places, List<PlaceAutocompleteException> errors}) setUpController() {
  final platform = FakePlatform();
  final places = <Place>[];
  final errors = <PlaceAutocompleteException>[];
  final c = PlaceAutocompleteController();
  c.attach(PlaceAutocompleteConfig(
    api: FlPlaceAutocomplete(platform: platform),
    options: PredictionOptions(),
    fields: defaultPlaceFields,
    onPlaceSelected: places.add,
    onError: errors.add,
  ));
  return (platform: platform, c: c, places: places, errors: errors);
}

void main() {
  test('initial text, setText and setPlace never call the platform', () {
    fakeAsync((async) {
      final platform = FakePlatform();
      final c = PlaceAutocompleteController(text: 'Initial');
      c.attach(PlaceAutocompleteConfig(api: FlPlaceAutocomplete(platform: platform), options: PredictionOptions(), fields: defaultPlaceFields));
      c.setText('Other');
      c.setPlace(const Place(id: 'x', formattedAddress: 'Addr'));
      async.elapse(const Duration(seconds: 2));
      expect(platform.totalCalls, 0);
      expect(c.textController.text, 'Addr');
      expect(c.selectedPlace!.id, 'x');
      expect(c.overlayOpen, isFalse);
    });
  });

  test('caret-only changes do not trigger a request', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      final before = t.platform.findCalls.length;
      t.c.textController.selection = const TextSelection.collapsed(offset: 2);
      async.elapse(const Duration(seconds: 1));
      expect(t.platform.findCalls.length, before);
    });
  });

  test('debounces typing and reuses one session', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pi';
      async.elapse(const Duration(milliseconds: 100));
      t.c.textController.text = 'piz';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.platform.findCalls.map((e) => e.input), ['piz']);
      t.c.textController.text = 'pizz';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.platform.findCalls.map((e) => e.sessionId).toSet().length, 1);
      expect(t.c.status, PlaceAutocompleteStatus.results);
      expect(t.c.overlayOpen, isTrue);
    });
  });

  test('below minChars no request is made', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'p';
      async.elapse(debounce * 2);
      expect(t.platform.totalCalls, 0);
      expect(t.c.status, PlaceAutocompleteStatus.idle);
    });
  });

  test('stale response from an older query is dropped', () {
    fakeAsync((async) {
      final t = setUpController();
      final first = Completer<List<PlacePrediction>>();
      t.platform.onFind = (input) => input == 'pi' ? first.future : Future.value([prediction('new')]);
      t.c.textController.text = 'pi';
      async.elapse(debounce);
      t.c.textController.text = 'piz';
      async.elapse(debounce);
      async.flushMicrotasks();
      first.complete([prediction('old')]);
      async.flushMicrotasks();
      expect(t.c.predictions.single.placeId, 'new');
    });
  });

  test('select fetches details with the same session, ends it, fires callback once', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final sid = t.platform.findCalls.single.sessionId;
      t.c.select(t.c.predictions.single);
      async.flushMicrotasks();
      expect(t.platform.fetchCalls.single.sessionId, sid);
      expect(t.platform.fetchCalls.single.fields, defaultPlaceFields);
      expect(t.places.single.location, const LatLng(1, 2));
      expect(t.c.selectedPlace, isNotNull);
      expect(t.c.session, isNull);
      expect(t.c.overlayOpen, isFalse);
      // next typing starts a fresh session
      t.c.textController.text = 'pizzas';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.platform.findCalls.last.sessionId, isNot(sid));
    });
  });

  test('selection does not trigger a new prediction request', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.select(t.c.predictions.single);
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(t.platform.findCalls.length, 1);
    });
  });

  test('stale prediction response after selection does not reopen overlay or change text', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final late = Completer<List<PlacePrediction>>();
      t.platform.onFind = (_) => late.future;
      t.c.textController.text = 'pizzas';
      async.elapse(debounce); // request in flight
      t.c.select(prediction('p-1', text: 'Chosen'));
      async.flushMicrotasks();
      late.complete([prediction('stale')]);
      async.flushMicrotasks();
      expect(t.c.overlayOpen, isFalse);
      expect(t.c.textController.text, 'Chosen');
      expect(t.c.predictions, isEmpty);
    });
  });

  test('editing text while the details fetch is in flight discards the result', () {
    fakeAsync((async) {
      final t = setUpController();
      final fetch = Completer<Place>();
      t.platform.onFetch = (_) => fetch.future;
      t.c.select(prediction('p', text: 'Chosen'));
      t.c.textController.text = 'Chosen but edited';
      fetch.complete(const Place(id: 'p'));
      async.flushMicrotasks();
      expect(t.c.selectedPlace, isNull);
      expect(t.places, isEmpty);
    });
  });

  test('fetch failure keeps the session active, reports the error, and retry succeeds', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final session = t.c.session!;
      t.platform.onFetch = (_) => Future.error(const PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.networkError));
      t.c.select(t.c.predictions.single);
      async.flushMicrotasks();
      expect(t.errors.single.code, PlaceAutocompleteErrorCode.networkError);
      expect(t.c.status, PlaceAutocompleteStatus.error);
      expect(session.isEnded, isFalse);
      t.platform.onFetch = null;
      t.c.retry();
      async.flushMicrotasks();
      expect(t.places.single.id, 'pizza-1');
      expect(session.isEnded, isTrue);
    });
  });

  test('prediction failure surfaces error status and onError', () {
    fakeAsync((async) {
      final t = setUpController();
      t.platform.onFind = (_) => Future.error(const PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.quotaExceeded));
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      expect(t.c.status, PlaceAutocompleteStatus.error);
      expect(t.errors.single.code, PlaceAutocompleteErrorCode.quotaExceeded);
    });
  });

  test('blur without selection disposes the session; blur during selection does not', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      final sid = t.c.session!.id;
      t.c.onFocusLost();
      async.flushMicrotasks();
      expect(t.platform.disposed, [sid]);
      expect(t.c.overlayOpen, isFalse);

      final fetch = Completer<Place>();
      t.platform.onFetch = (_) => fetch.future;
      t.c.textController.text = 'tacos';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.select(t.c.predictions.single);
      t.c.onFocusLost();
      fetch.complete(const Place(id: 'tacos-1'));
      async.flushMicrotasks();
      expect(t.platform.disposed.length, 1);
      expect(t.places.single.id, 'tacos-1');
    });
  });

  test('clear resets text, selection and disposes the session', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.clear();
      async.flushMicrotasks();
      expect(t.c.textController.text, '');
      expect(t.platform.disposed.length, 1);
      expect(t.c.status, PlaceAutocompleteStatus.idle);
    });
  });

  test('fetchDetailsOnSelect=false hands the live session to the app', () {
    fakeAsync((async) {
      final platform = FakePlatform();
      final picked = <PlacePrediction>[];
      final c = PlaceAutocompleteController();
      c.attach(PlaceAutocompleteConfig(
        api: FlPlaceAutocomplete(platform: platform), options: PredictionOptions(), fields: defaultPlaceFields,
        fetchDetailsOnSelect: false, onPredictionSelected: picked.add));
      c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      c.select(c.predictions.single);
      async.flushMicrotasks();
      expect(platform.fetchCalls, isEmpty);
      final s = c.takeSession();
      expect(s, isNotNull);
      expect(s!.isEnded, isFalse);
      expect(c.session, isNull);
      expect(picked, hasLength(1));
    });
  });

  test('dispose mid-debounce and mid-request does not throw', () {
    fakeAsync((async) {
      final t = setUpController();
      t.c.textController.text = 'pizza';
      t.c.dispose();
      async.elapse(debounce * 2);
      async.flushMicrotasks();

      final t2 = setUpController();
      final slow = Completer<List<PlacePrediction>>();
      t2.platform.onFind = (_) => slow.future;
      t2.c.textController.text = 'pizza';
      async.elapse(debounce);
      t2.c.dispose();
      slow.complete([prediction('x')]);
      async.flushMicrotasks();
    });
  });

  test('keyboard highlight wraps and selectHighlighted selects', () {
    fakeAsync((async) {
      final t = setUpController();
      t.platform.onFind = (_) => Future.value([prediction('a'), prediction('b')]);
      t.c.textController.text = 'pizza';
      async.elapse(debounce);
      async.flushMicrotasks();
      t.c.moveHighlight(1);
      t.c.moveHighlight(1);
      expect(t.c.highlightedIndex, 1);
      t.c.moveHighlight(1);
      expect(t.c.highlightedIndex, 0);
      t.c.moveHighlight(-1);
      expect(t.c.highlightedIndex, 1);
      t.c.selectHighlighted();
      async.flushMicrotasks();
      expect(t.platform.fetchCalls.single.placeId, 'b');
    });
  });
}
```

- [ ] **Step 2: Run** `flutter test test/controller_test.dart` → FAIL.

- [ ] **Step 3: Implement `controller.dart`**

```dart
import 'dart:async';

import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter/widgets.dart';

import '../api.dart';

/// Default fields fetched on selection.
const Set<PlaceField> defaultPlaceFields = {PlaceField.location, PlaceField.displayName, PlaceField.formattedAddress};

/// Lifecycle state of the suggestions list.
enum PlaceAutocompleteStatus {
  /// Nothing to show.
  idle,
  /// A request is in flight.
  loading,
  /// Predictions available.
  results,
  /// Request completed with no predictions.
  empty,
  /// The last operation failed.
  error,
}

/// Behaviour configuration attached by [PlaceAutocompleteField] (or manually).
class PlaceAutocompleteConfig {
  /// Creates a configuration.
  const PlaceAutocompleteConfig({
    required this.api,
    required this.options,
    required this.fields,
    this.debounce = const Duration(milliseconds: 300),
    this.minChars = 2,
    this.fetchDetailsOnSelect = true,
    this.onPredictionSelected,
    this.onPlaceSelected,
    this.onError,
  });

  /// API used for requests.
  final FlPlaceAutocomplete api;
  /// Prediction options.
  final PredictionOptions options;
  /// Fields requested on selection.
  final Set<PlaceField> fields;
  /// Debounce between keystrokes and requests.
  final Duration debounce;
  /// Minimum characters before querying.
  final int minChars;
  /// Whether selecting a prediction fetches full details.
  final bool fetchDetailsOnSelect;
  /// Called when a prediction is chosen.
  final void Function(PlacePrediction)? onPredictionSelected;
  /// Called with full details after a successful fetch.
  final void Function(Place)? onPlaceSelected;
  /// Called when a request fails.
  final void Function(PlaceAutocompleteException)? onError;
}

/// Holds the text, suggestions and session state of an autocomplete field.
class PlaceAutocompleteController extends ChangeNotifier {
  /// Creates a controller; [text] is set without any API call.
  PlaceAutocompleteController({String text = ''})
      : textController = TextEditingController(text: text),
        _lastText = text {
    textController.addListener(_onTextChanged);
  }

  /// The underlying text controller.
  final TextEditingController textController;

  PlaceAutocompleteConfig? _config;
  PlaceSession? _session;
  Timer? _debounce;
  int _generation = 0;
  int _selectionId = 0;
  bool _suppress = false;
  bool _disposed = false;
  bool _selecting = false;
  bool _overlayOpen = false;
  String _lastText;
  List<PlacePrediction> _predictions = const [];
  PlaceAutocompleteStatus _status = PlaceAutocompleteStatus.idle;
  PlaceAutocompleteException? _error;
  Place? _selectedPlace;
  int _highlighted = -1;
  VoidCallback? _retry;

  /// Current list state.
  PlaceAutocompleteStatus get status => _status;
  /// Current predictions.
  List<PlacePrediction> get predictions => _predictions;
  /// Last error, if [status] is error.
  PlaceAutocompleteException? get error => _error;
  /// Place chosen by the user (or set via [setPlace]).
  Place? get selectedPlace => _selectedPlace;
  /// Keyboard-highlighted row, or -1.
  int get highlightedIndex => _highlighted;
  /// Whether the suggestions overlay should be shown.
  bool get overlayOpen => _overlayOpen;
  /// Current live session, if any.
  PlaceSession? get session => _session;

  /// Applies configuration. Cheap; call on every widget update.
  void attach(PlaceAutocompleteConfig config) => _config = config;

  void _onTextChanged() {
    final text = textController.text;
    if (text == _lastText) return; // caret/selection/composing change only
    _lastText = text;
    if (_suppress) return;
    _onUserInput(text);
  }

  void _onUserInput(String text) {
    final config = _config;
    if (config == null) return;
    _selectedPlace = null;
    _debounce?.cancel();
    final generation = ++_generation;
    _highlighted = -1;
    if (text.trim().length < config.minChars) {
      _overlayOpen = false;
      _setState(PlaceAutocompleteStatus.idle, predictions: const []);
      return;
    }
    _overlayOpen = true;
    _debounce = Timer(config.debounce, () => _runQuery(text, generation));
    notifyListeners();
  }

  Future<void> _runQuery(String text, int generation) async {
    final config = _config;
    if (config == null || _disposed || generation != _generation) return;
    final session = _session ??= config.api.newSession();
    _error = null;
    _setState(PlaceAutocompleteStatus.loading);
    try {
      final result = await config.api.findPredictions(text, session: session, options: config.options);
      if (_disposed || generation != _generation) return;
      _highlighted = -1;
      _setState(result.isEmpty ? PlaceAutocompleteStatus.empty : PlaceAutocompleteStatus.results, predictions: result);
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _retry = () => _runQuery(text, generation);
      _fail(e);
    }
  }

  /// Selects [prediction]: closes the list, sets the text, and (by default)
  /// fetches full details with the current session.
  Future<void> select(PlacePrediction prediction) async {
    final config = _config;
    if (config == null || _disposed) return;
    _debounce?.cancel();
    _generation++;
    final selectionId = ++_selectionId;
    _selecting = true;
    _setTextProgrammatically(prediction.fullText);
    _overlayOpen = false;
    _highlighted = -1;
    _selectedPlace = null;
    _setState(PlaceAutocompleteStatus.idle, predictions: const []);
    config.onPredictionSelected?.call(prediction);
    if (!config.fetchDetailsOnSelect) {
      _selecting = false;
      return;
    }
    final session = _session;
    try {
      final place = await config.api.fetchPlace(
        prediction.placeId,
        session: session,
        fields: config.fields,
        languageCode: config.options.languageCode,
        regionCode: config.options.regionCode,
      );
      if (session != null && session.isEnded && identical(_session, session)) _session = null;
      if (_disposed || selectionId != _selectionId) return;
      _selectedPlace = place;
      notifyListeners();
      config.onPlaceSelected?.call(place);
    } catch (e) {
      if (_disposed || selectionId != _selectionId) return;
      _retry = () => select(prediction);
      _overlayOpen = true;
      _fail(e);
    } finally {
      if (selectionId == _selectionId) _selecting = false;
    }
  }

  /// Retries the last failed operation.
  void retry() {
    final r = _retry;
    _retry = null;
    r?.call();
  }

  /// Moves the keyboard highlight by [delta], wrapping around.
  void moveHighlight(int delta) {
    if (_predictions.isEmpty) return;
    final n = _predictions.length;
    _highlighted = _highlighted == -1 ? (delta > 0 ? 0 : n - 1) : (_highlighted + delta) % n;
    notifyListeners();
  }

  /// Selects the highlighted row, if any.
  Future<void> selectHighlighted() async {
    if (_highlighted >= 0 && _highlighted < _predictions.length) {
      await select(_predictions[_highlighted]);
    }
  }

  /// Closes the suggestion list without touching the text.
  void dismiss() {
    if (!_overlayOpen) return;
    _overlayOpen = false;
    notifyListeners();
  }

  /// Sets the text programmatically. Never calls the API.
  void setText(String text) {
    _reset();
    _setTextProgrammatically(text);
    _selectedPlace = null;
    notifyListeners();
  }

  /// Sets [place] as selected without firing callbacks or calling the API.
  void setPlace(Place place, {String? text}) {
    _reset();
    _setTextProgrammatically(text ?? place.formattedAddress ?? place.displayName ?? '');
    _selectedPlace = place;
    notifyListeners();
  }

  /// Clears text, selection, results and the session.
  void clear() {
    _reset();
    _setTextProgrammatically('');
    _selectedPlace = null;
    notifyListeners();
  }

  /// Called when the field loses focus.
  void onFocusLost() {
    if (_selecting) return;
    _debounce?.cancel();
    _generation++;
    _overlayOpen = false;
    _cancelSession();
    _setState(PlaceAutocompleteStatus.idle, predictions: const []);
  }

  /// Detaches and returns the live session (for `fetchDetailsOnSelect: false`).
  PlaceSession? takeSession() {
    final s = _session;
    _session = null;
    return s;
  }

  void _reset() {
    _debounce?.cancel();
    _generation++;
    _selectionId++;
    _selecting = false;
    _overlayOpen = false;
    _highlighted = -1;
    _predictions = const [];
    _status = PlaceAutocompleteStatus.idle;
    _error = null;
    _cancelSession();
  }

  void _cancelSession() {
    final s = _session;
    _session = null;
    final config = _config;
    if (s != null && !s.isEnded && config != null) {
      unawaited(config.api.cancelSession(s).catchError((Object _) {}));
    }
  }

  void _setTextProgrammatically(String text) {
    _suppress = true;
    textController.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _lastText = text;
    _suppress = false;
  }

  void _setState(PlaceAutocompleteStatus status, {List<PlacePrediction>? predictions}) {
    _status = status;
    if (predictions != null) _predictions = predictions;
    notifyListeners();
  }

  void _fail(Object e) {
    final ex = e is PlaceAutocompleteException ? e : PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.unknown, message: '$e');
    _error = ex;
    _setState(PlaceAutocompleteStatus.error);
    _config?.onError?.call(ex);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _cancelSession();
    textController.dispose();
    super.dispose();
  }
}
```

Export from `fl_place_autocomplete.dart`: `export 'src/widget/controller.dart';`

- [ ] **Step 4: Run** `flutter test test/controller_test.dart` → PASS. If a test fails because of ordering assumptions, fix the **controller**, not the test, unless the test contradicts the spec.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: PlaceAutocompleteController with session lifecycle and stale-response handling"
```

---

### Task 8: PlaceAutocompleteField widget and default builders

**Files:**
- Create: `fl_place_autocomplete/lib/src/widget/default_builders.dart`, `lib/src/widget/field.dart`
- Test: `fl_place_autocomplete/test/field_test.dart`

**Interfaces:**
- Consumes: `PlaceAutocompleteController`, `PlaceAutocompleteConfig`, `FlPlaceAutocomplete`.
- Produces:
  - Typedefs: `PlacePredictionBuilder = Widget Function(BuildContext, PlacePrediction, bool highlighted, VoidCallback onTap)`, `PlaceFieldBuilder = Widget Function(BuildContext, PlaceAutocompleteController, FocusNode, VoidCallback onSubmit)`, `PlaceLoadingBuilder = WidgetBuilder`, `PlaceEmptyBuilder = Widget Function(BuildContext, String query)`, `PlaceErrorBuilder = Widget Function(BuildContext, PlaceAutocompleteException, VoidCallback retry)`
  - `enum PlaceOverlayDirection { auto, up, down }`
  - `PlaceAutocompleteField` with every parameter in spec §5.1.
  - Defaults: `DefaultPredictionTile`, `defaultLoading`, `defaultEmpty`, `defaultError`, `defaultFooter` (text "Powered by Google").

- [ ] **Step 1: Failing widget tests** (`test/field_test.dart`)

```dart
import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_platform.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  late FakePlatform platform;
  late FlPlaceAutocomplete api;
  setUp(() {
    platform = FakePlatform();
    api = FlPlaceAutocomplete(platform: platform);
  });

  testWidgets('initialValue: no API call on build, focus, or pump', (tester) async {
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, initialValue: 'Eiffel Tower')));
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Eiffel Tower'), findsOneWidget);
    expect(platform.totalCalls, 0);
    expect(find.text('Powered by Google'), findsNothing); // overlay closed
  });

  testWidgets('initialPlace populates controller without onPlaceSelected', (tester) async {
    final c = PlaceAutocompleteController();
    var fired = 0;
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api, controller: c, initialPlace: const Place(id: 'p', formattedAddress: 'Addr'), onPlaceSelected: (_) => fired++)));
    expect(c.selectedPlace!.id, 'p');
    expect(find.text('Addr'), findsOneWidget);
    expect(fired, 0);
    expect(platform.totalCalls, 0);
  });

  testWidgets('typing shows predictions; tapping one fetches details and calls onPlaceSelected', (tester) async {
    Place? picked;
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, onPlaceSelected: (p) => picked = p)));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Text pizza-1'), findsOneWidget);
    expect(find.text('Powered by Google'), findsOneWidget);
    await tester.tap(find.text('Text pizza-1'));
    await tester.pump();
    await tester.pump();
    expect(picked!.location, const LatLng(1, 2));
    expect(platform.fetchCalls.single.sessionId, platform.findCalls.single.sessionId);
    expect(find.text('Text pizza-1'), findsOneWidget); // now in the text field only
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('custom predictionBuilder, emptyBuilder and footer are used', (tester) async {
    platform.onFind = (i) async => i == 'none' ? [] : [prediction('a')];
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api,
      predictionBuilder: (c, p, h, onTap) => TextButton(onPressed: onTap, child: Text('ROW ${p.placeId}')),
      emptyBuilder: (c, q) => Text('EMPTY $q'),
      footerBuilder: (c) => const Text('MY FOOTER'),
    )));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('ROW a'), findsOneWidget);
    expect(find.text('MY FOOTER'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'none');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('EMPTY none'), findsOneWidget);
  });

  testWidgets('errorBuilder shows and retry re-queries', (tester) async {
    var fail = true;
    platform.onFind = (_) => fail ? Future.error(const PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.networkError)) : Future.value([prediction('ok')]);
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api, errorBuilder: (c, e, retry) => TextButton(onPressed: retry, child: Text('ERR ${e.code.name}')))));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('ERR networkError'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('ERR networkError'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Text ok'), findsOneWidget);
  });

  testWidgets('keyboard: arrow down + enter selects; escape closes', (tester) async {
    Place? picked;
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api, onPlaceSelected: (p) => picked = p)));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(picked, isNotNull);

    await tester.enterText(find.byType(TextField), 'tacos');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('default tile tolerates empty secondary text and out-of-range matches', (tester) async {
    platform.onFind = (_) async => [
          const PlacePrediction(placeId: 'x', fullText: 'Ab', primaryText: 'Ab', secondaryText: '', matchedRanges: [MatchedRange(-4, 99)], types: []),
          const PlacePrediction(placeId: 'y', fullText: '', primaryText: '', secondaryText: '', matchedRanges: [MatchedRange(0, 3)], types: []),
        ];
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api)));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('disposing the field mid-request does not throw', (tester) async {
    platform.onFind = (_) => Future.delayed(const Duration(seconds: 1), () => [prediction('a')]);
    await tester.pumpWidget(host(PlaceAutocompleteField(api: api)));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fieldBuilder receives controller and focus node', (tester) async {
    await tester.pumpWidget(host(PlaceAutocompleteField(
      api: api,
      fieldBuilder: (c, controller, focusNode, onSubmit) => TextField(key: const Key('mine'), controller: controller.textController, focusNode: focusNode),
    )));
    await tester.enterText(find.byKey(const Key('mine')), 'pizza');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(platform.findCalls, hasLength(1));
  });
}
```
(Add `import 'package:flutter/services.dart';` for `LogicalKeyboardKey`.)

- [ ] **Step 2: Run** `flutter test test/field_test.dart` → FAIL.

- [ ] **Step 3: Implement `default_builders.dart`**

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter/material.dart';

/// Builds a suggestion row.
typedef PlacePredictionBuilder = Widget Function(BuildContext context, PlacePrediction prediction, bool highlighted, VoidCallback onTap);

/// Builds the "no results" state.
typedef PlaceEmptyBuilder = Widget Function(BuildContext context, String query);

/// Builds the error state.
typedef PlaceErrorBuilder = Widget Function(BuildContext context, PlaceAutocompleteException error, VoidCallback retry);

/// Default suggestion row: primary text with highlighted matches, secondary text below.
class DefaultPredictionTile extends StatelessWidget {
  /// Creates a tile.
  const DefaultPredictionTile({super.key, required this.prediction, required this.highlighted, required this.onTap});

  /// The prediction to show.
  final PlacePrediction prediction;
  /// Whether the row is keyboard-highlighted.
  final bool highlighted;
  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = prediction.primaryText;
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in prediction.matchesWithin(primary.length)) {
      if (r.start < cursor) continue;
      if (r.start > cursor) spans.add(TextSpan(text: primary.substring(cursor, r.start)));
      spans.add(TextSpan(text: primary.substring(r.start, r.end), style: const TextStyle(fontWeight: FontWeight.bold)));
      cursor = r.end;
    }
    if (cursor < primary.length) spans.add(TextSpan(text: primary.substring(cursor)));
    return ExcludeFocus(
      child: ListTile(
        dense: true,
        selected: highlighted,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        title: Text.rich(TextSpan(children: spans)),
        subtitle: prediction.secondaryText.isEmpty ? null : Text(prediction.secondaryText),
        onTap: onTap,
      ),
    );
  }
}

/// Default loading indicator.
Widget defaultLoading(BuildContext context) => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());

/// Default empty state.
Widget defaultEmpty(BuildContext context, String query) => const Padding(padding: EdgeInsets.all(12), child: Text('No results'));

/// Default error state.
Widget defaultError(BuildContext context, PlaceAutocompleteException error, VoidCallback retry) => ListTile(
      dense: true,
      title: Text(error.message ?? 'Something went wrong'),
      trailing: TextButton(onPressed: retry, child: const Text('Retry')),
    );

/// Default attribution footer.
Widget defaultFooter(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Align(alignment: Alignment.centerRight, child: Text('Powered by Google', style: Theme.of(context).textTheme.labelSmall)),
    );
```

- [ ] **Step 4: Implement `field.dart`.** Key points (write the full widget):

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import 'controller.dart';
import 'default_builders.dart';

/// Builds the text field yourself.
typedef PlaceFieldBuilder = Widget Function(BuildContext context, PlaceAutocompleteController controller, FocusNode focusNode, VoidCallback onSubmit);

/// Where the suggestion list opens.
enum PlaceOverlayDirection {
  /// Picks the side with more room.
  auto,
  /// Above the field.
  up,
  /// Below the field.
  down,
}

/// A Google Places autocomplete text field.
class PlaceAutocompleteField extends StatefulWidget {
  /// Creates the field.
  const PlaceAutocompleteField({
    super.key,
    this.api,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.initialPlace,
    this.options,
    this.fields = defaultPlaceFields,
    this.debounce = const Duration(milliseconds: 300),
    this.minChars = 2,
    this.fetchDetailsOnSelect = true,
    this.onPredictionSelected,
    this.onPlaceSelected,
    this.onError,
    this.decoration = const InputDecoration(),
    this.style,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.enabled,
    this.autofocus = false,
    this.overlayDecoration,
    this.overlayMaxHeight = 280,
    this.overlayElevation = 4,
    this.overlayOffset = Offset.zero,
    this.openDirection = PlaceOverlayDirection.auto,
    this.fieldBuilder,
    this.predictionBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.separatorBuilder,
    this.headerBuilder,
    this.footerBuilder,
  });
  // ... one documented final field per parameter above ...
}
```
State behaviour (must all be implemented):

1. `initState`: `_ownsController = widget.controller == null`; `_controller = widget.controller ?? PlaceAutocompleteController(text: widget.initialValue ?? '')`. If an external controller was given and `initialValue != null` call `_controller.setText(initialValue)`. If `initialPlace != null` call `_controller.setPlace(initialPlace)` **after** `_attach()`. `_ownsFocus` likewise; `_focusNode.addListener(_onFocus)`. Call `_attach()` (builds `PlaceAutocompleteConfig` from `widget`, using `widget.api ?? FlPlaceAutocomplete.instance`, `widget.options ?? PredictionOptions()`).
2. `didUpdateWidget`: call `_attach()` again (so callbacks are always current); swap controller/focus node if the widget's instances changed (remove/add listeners, dispose owned ones).
3. `_onFocus`: if `!_focusNode.hasFocus` → `_controller.onFocusLost()`. Gaining focus does nothing (no API call, overlay stays closed).
4. `dispose`: remove listeners; dispose owned controller/focus node.
5. `build`:

```dart
final field = widget.fieldBuilder?.call(context, _controller, _focusNode, _submit) ??
    TextField(
      controller: _controller.textController,
      focusNode: _focusNode,
      decoration: widget.decoration,
      style: widget.style,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      groupId: _tapGroup,
      onSubmitted: (_) => _submit(),
    );

return Focus(
  canRequestFocus: false,
  skipTraversal: true,
  onKeyEvent: _onKey,
  child: OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _buildOverlay,
    child: CompositedTransformTarget(link: _link, child: KeyedSubtree(key: _fieldKey, child: field)),
  ),
);
```
- `_portal = OverlayPortalController()`; show it whenever the focus node has focus (call `_portal.show()` in `_onFocus` when focused, `hide()` when not; also `_portal.show()` in `initState` post-frame if `autofocus`). The overlay child itself returns `SizedBox.shrink()` unless `_controller.overlayOpen`.
- `_onKey(node, event)`: only on `KeyDownEvent`/`KeyRepeatEvent` and only when `_controller.overlayOpen`; `arrowDown` → `moveHighlight(1)`, `arrowUp` → `moveHighlight(-1)`, `escape` → `dismiss()`, all return `KeyEventResult.handled`; `enter`/`numpadEnter` → if `highlightedIndex >= 0` call `selectHighlighted()` and return handled, else ignored. Everything else ignored.
- `_submit()`: `_controller.selectHighlighted()`.
- `_buildOverlay(context)`: `ListenableBuilder(listenable: _controller, builder: ...)`. When `!overlayOpen` return `const SizedBox.shrink()`. Otherwise compute width from `_fieldKey.currentContext?.findRenderObject() as RenderBox?` (`box.size.width`), decide direction: `up` if `openDirection == up`, or (`auto` and `spaceBelow < overlayMaxHeight && spaceAbove > spaceBelow`) where `spaceBelow = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom - (box.localToGlobal(Offset.zero).dy + box.size.height)` and `spaceAbove = box.localToGlobal(Offset.zero).dy`. Return:

```dart
CompositedTransformFollower(
  link: _link,
  showWhenUnlinked: false,
  targetAnchor: up ? Alignment.topLeft : Alignment.bottomLeft,
  followerAnchor: up ? Alignment.bottomLeft : Alignment.topLeft,
  offset: widget.overlayOffset,
  child: Align(
    alignment: up ? Alignment.bottomLeft : Alignment.topLeft,
    child: TapRegion(
      groupId: _tapGroup,
      child: SizedBox(
        width: width,
        child: Material(
          elevation: widget.overlayElevation,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.overlayMaxHeight),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (widget.headerBuilder != null) widget.headerBuilder!(context),
              Flexible(child: _buildBody(context)),
              (widget.footerBuilder ?? defaultFooter)(context),
            ]),
          ),
        ),
      ),
    ),
  ),
)
```
`overlayDecoration` (a `Decoration?`) wraps the inner `Material` child in a `DecoratedBox` when provided.
- `_buildBody`: by `_controller.status`:
  - `loading` and no predictions → `(loadingBuilder ?? defaultLoading)(context)`; `loading` with predictions → the list.
  - `results` (or loading with predictions) → `ListView.separated(shrinkWrap: true, padding: EdgeInsets.zero, itemCount, itemBuilder: (c, i) => (predictionBuilder ?? default)(c, p, i == highlightedIndex, () => _controller.select(p)), separatorBuilder: widget.separatorBuilder ?? (_, __) => const SizedBox.shrink())`, where default builds `DefaultPredictionTile`.
  - `empty` → `(emptyBuilder ?? defaultEmpty)(context, _controller.textController.text)`.
  - `error` → `(errorBuilder ?? defaultError)(context, _controller.error!, _controller.retry)`.
  - `idle` → `SizedBox.shrink()`.
- `_tapGroup = Object()` created once per state.

Export `src/widget/field.dart` and `src/widget/default_builders.dart` from `fl_place_autocomplete.dart`.

- [ ] **Step 5: Run** `flutter test test/field_test.dart` then `flutter test` (whole package). Expected: PASS. Fix the widget (not the tests) for failures; the only acceptable test edits are pump counts/timings.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: PlaceAutocompleteField widget with builders, keyboard and overlay"
```

---

### Task 9: Android implementation

**Files:**
- Modify: `fl_place_autocomplete_android/pubspec.yaml`, `android/build.gradle(.kts)`, `android/src/main/AndroidManifest.xml`
- Create: `lib/fl_place_autocomplete_android.dart`, `android/src/main/kotlin/com/mk7/fl_place_autocomplete_android/{FlPlaceAutocompleteAndroidPlugin,SessionStore,ErrorMapper,PlaceMapping}.kt`
- Test: `android/src/test/kotlin/com/mk7/fl_place_autocomplete_android/{SessionStoreTest,ErrorMapperTest}.kt`, `test/registration_test.dart`
- Generated (Task 5): `Messages.g.kt`

**Interfaces:**
- Consumes: Pigeon `PlacesHostApi` Kotlin interface (`initialize`, `disposeSession`, `findPredictions`, `fetchPlace`, `fetchPhoto`) with callbacks `(Result<T>) -> Unit`, errors as `FlutterError(code, message, details)`.
- Produces: `FlPlaceAutocompleteAndroid.registerWith()` Dart class setting `FlPlaceAutocompletePlatform.instance = PigeonPlacesPlatform()`.

- [ ] **Step 1: Dart registration + pubspec.** `pubspec.yaml`:

```yaml
dependencies:
  flutter: {sdk: flutter}
  fl_place_autocomplete_platform_interface: ^0.1.0
flutter:
  plugin:
    implements: fl_place_autocomplete
    platforms:
      android:
        package: com.mk7.fl_place_autocomplete_android
        pluginClass: FlPlaceAutocompleteAndroidPlugin
        dartPluginClass: FlPlaceAutocompleteAndroid
```
`lib/fl_place_autocomplete_android.dart`:

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';

/// Android implementation registration.
class FlPlaceAutocompleteAndroid {
  /// Registers the Pigeon-backed implementation.
  static void registerWith() {
    FlPlaceAutocompletePlatform.instance = PigeonPlacesPlatform();
  }
}
```
`test/registration_test.dart`:

```dart
import 'package:fl_place_autocomplete_android/fl_place_autocomplete_android.dart';
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registerWith installs the Pigeon platform', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlPlaceAutocompleteAndroid.registerWith();
    expect(FlPlaceAutocompletePlatform.instance, isA<PigeonPlacesPlatform>());
  });
}
```
Run `flutter test` (PASS after implementing the class). 

- [ ] **Step 2: Gradle.** In `android/build.gradle`: `namespace = "com.mk7.fl_place_autocomplete_android"`, `compileSdk = 35`, `defaultConfig { minSdk = 23 }`, Java/Kotlin 17, dependencies:

```gradle
dependencies {
    implementation("com.google.android.libraries.places:places:4.4.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("junit:junit:4.13.2")
}
```
(If `4.4.1` does not resolve, use the latest stable from Google's Places SDK for Android release notes; it must be >= 3.5.0.) Remove generated template test files that reference the template plugin class.

- [ ] **Step 3: Failing Kotlin unit tests** (pure Kotlin, no Android types)

`SessionStoreTest.kt`:

```kotlin
package com.mk7.fl_place_autocomplete_android

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertSame

class SessionStoreTest {
    @Test fun sameIdReturnsSameToken() {
        var n = 0
        val store = SessionStore { "token-${n++}" }
        assertSame(store.getOrCreate("a"), store.getOrCreate("a"))
        assertEquals(1, n)
    }
    @Test fun differentIdsGetDifferentTokens() {
        var n = 0
        val store = SessionStore { "token-${n++}" }
        assertNotEquals(store.getOrCreate("a"), store.getOrCreate("b"))
    }
    @Test fun removeDropsTheToken() {
        var n = 0
        val store = SessionStore { "token-${n++}" }
        val first = store.getOrCreate("a")
        store.remove("a")
        assertNotEquals(first, store.getOrCreate("a"))
    }
    @Test fun nullIdMeansNoToken() {
        val store = SessionStore { "t" }
        assertEquals(null, store.getOrNull(null))
    }
}
```
`ErrorMapperTest.kt`:

```kotlin
package com.mk7.fl_place_autocomplete_android

import kotlin.test.Test
import kotlin.test.assertEquals

class ErrorMapperTest {
    @Test fun mapsKnownStatusCodes() {
        assertEquals("invalidApiKey", ErrorMapper.codeFor(9011))   // REQUEST_DENIED
        assertEquals("quotaExceeded", ErrorMapper.codeFor(9010))   // OVER_QUERY_LIMIT
        assertEquals("networkError", ErrorMapper.codeFor(7))       // NETWORK_ERROR
        assertEquals("invalidRequest", ErrorMapper.codeFor(9012))  // INVALID_REQUEST
        assertEquals("notFound", ErrorMapper.codeFor(9013))        // NOT_FOUND
        assertEquals("unknown", ErrorMapper.codeFor(-1))
    }
}
```
Run: `cd fl_place_autocomplete_android/android && ./gradlew test` (generate the wrapper first from the example app build if needed — easiest: run via the Task 13 example app's `android/gradlew :fl_place_autocomplete_android:test`). Expected: FAIL (classes missing). **Verify the Places status-code constants** (`PlacesStatusCodes.REQUEST_DENIED` etc.) in the SDK's `PlacesStatusCodes` reference and fix the numbers in the test and `ErrorMapper` to match.

- [ ] **Step 4: Implement `SessionStore.kt` and `ErrorMapper.kt`**

```kotlin
package com.mk7.fl_place_autocomplete_android

class SessionStore<T : Any>(private val factory: () -> T) {
    private val tokens = HashMap<String, T>()
    @Synchronized fun getOrCreate(id: String): T = tokens.getOrPut(id, factory)
    @Synchronized fun getOrNull(id: String?): T? = id?.let { getOrCreate(it) }
    @Synchronized fun remove(id: String) { tokens.remove(id) }
}

object ErrorMapper {
    fun codeFor(statusCode: Int): String = when (statusCode) {
        9011 -> "invalidApiKey"
        9010 -> "quotaExceeded"
        7 -> "networkError"
        9012 -> "invalidRequest"
        9013 -> "notFound"
        else -> "unknown"
    }
}
```

- [ ] **Step 5: Implement the plugin** `FlPlaceAutocompleteAndroidPlugin.kt`:

```kotlin
package com.mk7.fl_place_autocomplete_android

import android.content.Context
import android.content.pm.PackageManager
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.*
import com.google.android.libraries.places.api.net.*
import io.flutter.embedding.engine.plugins.FlutterPlugin

class FlPlaceAutocompleteAndroidPlugin : FlutterPlugin, PlacesHostApi {
    private lateinit var context: Context
    private var client: PlacesClient? = null
    private val sessions = SessionStore { AutocompleteSessionToken.newInstance() }
    private val photos = PhotoStore()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        PlacesHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PlacesHostApi.setUp(binding.binaryMessenger, null)
    }

    private fun placesClient(): PlacesClient {
        client?.let { return it }
        val key = context.packageManager
            .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            .metaData?.getString("com.google.android.geo.API_KEY")
        if (key.isNullOrBlank()) {
            throw FlutterError("invalidApiKey", "Missing meta-data com.google.android.geo.API_KEY in AndroidManifest.xml", null)
        }
        if (!Places.isInitialized()) Places.initializeWithNewPlacesApiEnabled(context, key)
        return Places.createClient(context).also { client = it }
    }

    private fun fail(e: Exception): FlutterError = when (e) {
        is FlutterError -> e
        is ApiException -> FlutterError(ErrorMapper.codeFor(e.statusCode), e.message, null)
        else -> FlutterError("unknown", e.message, null)
    }

    override fun initialize(callback: (Result<Unit>) -> Unit) {
        try { placesClient(); callback(Result.success(Unit)) } catch (e: Exception) { callback(Result.failure(fail(e))) }
    }

    override fun disposeSession(sessionId: String) { sessions.remove(sessionId) }

    override fun findPredictions(input: String, sessionId: String?, options: OptionsMsg, callback: (Result<List<PredictionMsg>>) -> Unit) {
        try {
            val builder = FindAutocompletePredictionsRequest.builder().setQuery(input)
            sessions.getOrNull(sessionId)?.let { builder.setSessionToken(it) }
            options.locationBias?.let { builder.setLocationBias(it.toBias()) }
            options.locationRestriction?.let { builder.setLocationRestriction(it.toRectangle()) }
            options.origin?.let { builder.setOrigin(LatLng(it.latitude, it.longitude)) }
            if (options.includedPrimaryTypes.isNotEmpty()) builder.setTypesFilter(options.includedPrimaryTypes)
            if (options.includedRegionCodes.isNotEmpty()) builder.setCountries(options.includedRegionCodes)
            options.regionCode?.let { builder.setRegionCode(it) }
            options.inputOffset?.let { builder.setInputOffset(it.toInt()) }
            placesClient().findAutocompletePredictions(builder.build())
                .addOnSuccessListener { r -> callback(Result.success(r.autocompletePredictions.map { it.toMsg() })) }
                .addOnFailureListener { callback(Result.failure(fail(it as Exception))) }
        } catch (e: Exception) { callback(Result.failure(fail(e))) }
    }

    override fun fetchPlace(placeId: String, sessionId: String?, fields: List<String>, languageCode: String?, regionCode: String?, callback: (Result<PlaceMsg>) -> Unit) {
        try {
            val placeFields = fields.mapNotNull { fieldFor(it) }.toMutableList()
            val builder = FetchPlaceRequest.builder(placeId, placeFields)
            sessions.getOrNull(sessionId)?.let { builder.setSessionToken(it) }
            regionCode?.let { builder.setRegionCode(it) }
            placesClient().fetchPlace(builder.build())
                .addOnSuccessListener { r ->
                    sessionId?.let { sessions.remove(it) } // Place Details ends the session
                    callback(Result.success(r.place.toMsg(fields.toSet(), photos)))
                }
                .addOnFailureListener { callback(Result.failure(fail(it as Exception))) }
        } catch (e: Exception) { callback(Result.failure(fail(e))) }
    }

    override fun fetchPhoto(ref: PhotoRefMsg, maxWidth: Long?, maxHeight: Long?, callback: (Result<PhotoDataMsg>) -> Unit) {
        val metadata = photos.get(ref.id)
        if (metadata == null) {
            callback(Result.failure(FlutterError("notFound", "Unknown photo id ${ref.id}; fetch the place again.", null)))
            return
        }
        val builder = FetchResolvedPhotoUriRequest.builder(metadata)
        maxWidth?.let { builder.setMaxWidth(it.toInt()) }
        maxHeight?.let { builder.setMaxHeight(it.toInt()) }
        placesClient().fetchResolvedPhotoUri(builder.build())
            .addOnSuccessListener { callback(Result.success(PhotoDataMsg(bytes = null, uri = it.uri?.toString()))) }
            .addOnFailureListener { callback(Result.failure(fail(it as Exception))) }
    }
}
```
**Failure on `sessionId` failure semantics:** the token is removed only inside `addOnSuccessListener` so a failed fetch keeps the session usable (matches the Dart rule).

`PlaceMapping.kt` contains: `AreaMsg.toBias()` (circle → `CircularBounds.newInstance(LatLng, radius)`, rectangle → `RectangularBounds.newInstance(sw, ne)`), `LatLngBoundsMsg.toRectangle()`, `AutocompletePrediction.toMsg()`, `fieldFor(name: String): Place.Field?` (a `when` over the 23 `PlaceField` names to the matching `Place.Field` constant, e.g. `"displayName" -> Place.Field.DISPLAY_NAME`, `"location" -> Place.Field.LOCATION`, `"regularOpeningHours" -> Place.Field.CURRENT_OPENING_HOURS`/`OPENING_HOURS` as the SDK defines, `"photos" -> Place.Field.PHOTO_METADATAS`), `Place.toMsg(requested: Set<String>, photos: PhotoStore)` (populates **only** fields in `requested`), and `class PhotoStore` (`LinkedHashMap` LRU capped at 200, `put(metadata): String` returns an id like `UUID`, `get(id)`).

`AutocompletePrediction.toMsg()`:

```kotlin
fun AutocompletePrediction.toMsg(): PredictionMsg {
    val full = getFullText(null)
    return PredictionMsg(
        placeId = placeId,
        fullText = full.toString(),
        primaryText = getPrimaryText(null).toString(),
        secondaryText = getSecondaryText(null).toString(),
        matchedRanges = full.matchedRanges(),
        types = placeTypes,
        distanceMeters = distanceMeters?.toLong(),
    )
}

/** Matched ranges are UTF-16 offsets; Android spans already use them. */
fun CharSequence.matchedRanges(): List<MatchedRangeMsg> {
    val spanned = this as? android.text.Spanned ?: return emptyList()
    return spanned.getSpans(0, length, android.text.style.CharacterStyle::class.java).map {
        MatchedRangeMsg(start = spanned.getSpanStart(it).toLong(), end = spanned.getSpanEnd(it).toLong())
    }.sortedBy { it.start }
}
```
Pigeon maps Dart `int` to Kotlin `Long`; use `.toLong()`/`.toInt()` conversions wherever the compiler requires them.

- [ ] **Step 6: Compile and fix.** The SDK getter names in `PlaceMapping.kt` follow the New-API `Place` class (e.g. `displayName`, `formattedAddress`, `location`, `viewport`, `addressComponents`, `placeTypes`, `primaryType`, `rating`, `userRatingCount`, `priceLevel`, `nationalPhoneNumber`, `internationalPhoneNumber`, `websiteUri`, `googleMapsUri`, `utcOffsetMinutes`, `businessStatus`, `editorialSummary`, `openingHours`, `photoMetadatas`, `reviews`). Run `./gradlew :fl_place_autocomplete_android:compileDebugKotlin` from the example app's `android/` (after Task 13 creates it; until then create a throwaway app in the scratchpad: `flutter create tmp_app` + path dependency). For every unresolved symbol consult the Places SDK for Android reference, fix the mapping; **do not change the Pigeon contract**. Priority mapping rules: `priceLevel` 0..4 → `free|inexpensive|moderate|expensive|veryExpensive`; `businessStatus` enum → `operational|closedTemporarily|closedPermanently`; each `PhotoMetadata` is stored with `photos.put(...)` and its id returned in `PhotoRefMsg.id`.

- [ ] **Step 7: Run tests**

Run: `flutter test` (package) and the Gradle unit tests.
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat(android): Places SDK (New) implementation with session store"
```

---

### Task 10: Web implementation — pure mapping and session cache

**Files:**
- Create: `fl_place_autocomplete_web/lib/src/web_mapping.dart`, `lib/src/session_cache.dart`
- Test: `fl_place_autocomplete_web/test/web_mapping_test.dart`, `test/session_cache_test.dart`

**Interfaces:**
- Produces (pure Dart, no JS):
  - `Map<String, Object?> requestFromOptions(String input, PredictionOptions o)` → the JS request map: `input`, `locationBias`, `locationRestriction`, `origin`, `includedPrimaryTypes`, `includedRegionCodes`, `language`, `region`, `inputOffset` (omit nulls/empties). Shapes: circle bias `{center:{lat,lng}, radius}`, rectangle bias/restriction `{south,west,north,east}`, origin `{lat,lng}`.
  - `PlacePrediction predictionFromWeb(Map<String, Object?> json)` where json = `{placeId, text, mainText, secondaryText, types, distanceMeters, matches:[{startOffset,endOffset}]}`.
  - `Place placeFromWebJson(Map<Object?, Object?> json, {required String Function(int index) photoIdFor})` mapping the `Place.toJSON()` shape.
  - `PlaceAutocompleteException webError(Object error)` (message heuristics).
  - `class SessionCache<TToken, TPrediction>`: `entry(id)` (creates with `tokenFactory`), `cachePrediction(id, placeId, prediction)`, `prediction(id, placeId)`, `remove(id)`.

- [ ] **Step 1: Failing tests**

`session_cache_test.dart`:

```dart
import 'package:fl_place_autocomplete_web/src/session_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same id shares the token and predictions; remove drops them', () {
    var n = 0;
    final cache = SessionCache<String, String>(() => 'tok${n++}');
    final a = cache.entry('s1');
    cache.cachePrediction('s1', 'p1', 'pred1');
    expect(cache.entry('s1').token, a.token);
    expect(cache.prediction('s1', 'p1'), 'pred1');
    cache.remove('s1');
    expect(cache.prediction('s1', 'p1'), isNull);
    expect(cache.entry('s1').token, isNot(a.token));
  });
  test('predictions from different sessions do not mix', () {
    final cache = SessionCache<String, String>(() => 't');
    cache.cachePrediction('a', 'p', 'A');
    cache.cachePrediction('b', 'p', 'B');
    expect(cache.prediction('a', 'p'), 'A');
    expect(cache.prediction('b', 'p'), 'B');
  });
}
```
`web_mapping_test.dart`:

```dart
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_web/src/web_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('request omits nulls and maps circle bias, origin and language', () {
    final r = requestFromOptions('pi', PredictionOptions(
      locationBias: const CircularArea(center: LatLng(1, 2), radiusMeters: 500),
      origin: const LatLng(3, 4), includedRegionCodes: ['us'], languageCode: 'en', regionCode: 'us'));
    expect(r['input'], 'pi');
    expect(r['locationBias'], {'center': {'lat': 1.0, 'lng': 2.0}, 'radius': 500.0});
    expect(r['origin'], {'lat': 3.0, 'lng': 4.0});
    expect(r['includedRegionCodes'], ['us']);
    expect(r['language'], 'en');
    expect(r['region'], 'us');
    expect(r.containsKey('locationRestriction'), isFalse);
    expect(r.containsKey('includedPrimaryTypes'), isFalse);
  });
  test('request maps rectangle restriction', () {
    final r = requestFromOptions('x', PredictionOptions(
      locationRestriction: const LatLngBounds(southwest: LatLng(0, 1), northeast: LatLng(2, 3))));
    expect(r['locationRestriction'], {'south': 0.0, 'west': 1.0, 'north': 2.0, 'east': 3.0});
  });
  test('prediction maps matches and tolerates missing secondary text', () {
    final p = predictionFromWeb({
      'placeId': 'p', 'text': 'A, B', 'mainText': 'A', 'secondaryText': null, 'types': ['x'], 'distanceMeters': 7,
      'matches': [{'startOffset': 0, 'endOffset': 1}],
    });
    expect(p.secondaryText, '');
    expect(p.matchedRanges.single.end, 1);
    expect(p.distanceMeters, 7);
  });
  test('place maps toJSON shape', () {
    final place = placeFromWebJson({
      'id': 'p', 'displayName': 'N', 'location': {'lat': 1.5, 'lng': 2.5},
      'viewport': {'south': 0, 'west': 1, 'north': 2, 'east': 3},
      'priceLevel': 'VERY_EXPENSIVE', 'businessStatus': 'CLOSED_TEMPORARILY',
      'websiteURI': 'https://x.dev',
      'regularOpeningHours': {'weekdayDescriptions': ['Mon'], 'periods': [{'open': {'day': 1, 'hour': 9, 'minute': 0}}]},
      'photos': [{'widthPx': 10, 'heightPx': 20, 'authorAttributions': [{'displayName': 'N'}]}],
    }, photoIdFor: (i) => 'ph$i');
    expect(place.location, const LatLng(1.5, 2.5));
    expect(place.viewport!.northeast, const LatLng(2, 3));
    expect(place.priceLevel, PriceLevel.veryExpensive);
    expect(place.businessStatus, BusinessStatus.closedTemporarily);
    expect(place.photos!.single.id, 'ph0');
    expect(place.regularOpeningHours!.periods.single.open!.hour, 9);
    expect(place.reviews, isNull);
  });
  test('webError maps messages', () {
    expect(webError('InvalidKeyMapError').code, PlaceAutocompleteErrorCode.invalidApiKey);
    expect(webError('OVER_QUERY_LIMIT').code, PlaceAutocompleteErrorCode.quotaExceeded);
    expect(webError('NOT_FOUND').code, PlaceAutocompleteErrorCode.notFound);
    expect(webError('INVALID_REQUEST').code, PlaceAutocompleteErrorCode.invalidRequest);
    expect(webError('Failed to fetch').code, PlaceAutocompleteErrorCode.networkError);
    expect(webError('???').code, PlaceAutocompleteErrorCode.unknown);
  });
}
```
Run `flutter test --platform chrome` → FAIL.

- [ ] **Step 2: Implement** `session_cache.dart`:

```dart
/// Per-session state for the web implementation.
class SessionEntry<TToken, TPrediction> {
  /// Creates an entry.
  SessionEntry(this.token);
  /// The JS `AutocompleteSessionToken`.
  final TToken token;
  /// Original JS prediction objects, keyed by place id. Needed because only
  /// `placePrediction.toPlace()` carries the session token into `fetchFields`.
  final Map<String, TPrediction> predictions = {};
}

/// Maps Dart session ids to web session state.
class SessionCache<TToken, TPrediction> {
  /// Creates a cache; [tokenFactory] builds a new token.
  SessionCache(this._tokenFactory);
  final TToken Function() _tokenFactory;
  final Map<String, SessionEntry<TToken, TPrediction>> _entries = {};

  /// Gets or creates the entry for [id].
  SessionEntry<TToken, TPrediction> entry(String id) => _entries.putIfAbsent(id, () => SessionEntry(_tokenFactory()));

  /// Remembers [prediction] for [placeId] in session [id].
  void cachePrediction(String id, String placeId, TPrediction prediction) => entry(id).predictions[placeId] = prediction;

  /// Returns the cached prediction, if any.
  TPrediction? prediction(String id, String placeId) => _entries[id]?.predictions[placeId];

  /// Drops session [id].
  void remove(String id) => _entries.remove(id);
}
```
`web_mapping.dart` — implement the five functions per the tests. Helper conventions: `_num(Object?)` → `(v as num?)?.toDouble()`; `LatLng` from `{lat,lng}`; viewport from `{south,west,north,east}`; enums: `'VERY_EXPENSIVE'` → `veryExpensive` via a small `_camel(String upperSnake)`; website key `websiteURI` (fallback `websiteUri`), maps key `googleMapsURI` (fallback `googleMapsUri`); photos use `photoIdFor(index)`; `webError` lowercases the message and checks `invalidkey|api key|apikey|referernotallowed` → invalidApiKey, `over_query_limit|quota` → quotaExceeded, `not_found` → notFound, `invalid_request|invalidrequest` → invalidRequest, `failed to fetch|network` → networkError, else unknown; message preserved.

- [ ] **Step 3: Run** `flutter test --platform chrome` → PASS. **Step 4: Commit**

```bash
git add -A && git commit -m "feat(web): request/response mapping and session cache"
```

---

### Task 11: Web implementation — JS interop platform

**Files:**
- Create: `fl_place_autocomplete_web/lib/fl_place_autocomplete_web.dart`, `lib/src/js_places.dart`
- Modify: `pubspec.yaml`
- Test: `test/web_platform_test.dart` (Chrome, stubbed `google.maps`)

**Interfaces:**
- Consumes: Task 10 helpers, `FlPlaceAutocompletePlatform`.
- Produces: `FlPlaceAutocompleteWeb extends FlPlaceAutocompletePlatform` with `static void registerWith(Registrar registrar)`.

- [ ] **Step 1: Pubspec**

```yaml
dependencies:
  flutter: {sdk: flutter}
  flutter_web_plugins: {sdk: flutter}
  fl_place_autocomplete_platform_interface: ^0.1.0
  web: ^1.1.0
flutter:
  plugin:
    implements: fl_place_autocomplete
    platforms:
      web:
        pluginClass: FlPlaceAutocompleteWeb
        fileName: fl_place_autocomplete_web.dart
```

- [ ] **Step 2: Failing test with a stubbed Maps API** (`test/web_platform_test.dart`, `@TestOn('browser')`)

```dart
@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:fl_place_autocomplete_web/fl_place_autocomplete_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// Installs a fake `google.maps` that records calls on `window.__calls`.
void installStub() {
  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.text = '''
    window.__calls = [];
    class Token { constructor(){ this.n = (window.__tokens = (window.__tokens||0)+1); } }
    class Place {
      constructor(init){ this.init = init; this.viaPrediction = false; }
      async fetchFields(o){ window.__calls.push({fn:'fetchFields', fields:o.fields, viaPrediction:this.viaPrediction, id:this.init.id, token:this.token&&this.token.n}); }
      toJSON(){ return {id:this.init.id, displayName:'N', location:{lat:1,lng:2}}; }
    }
    window.google = { maps: { importLibrary: async (n) => ({
      AutocompleteSessionToken: Token,
      Place,
      AutocompleteSuggestion: { fetchAutocompleteSuggestions: async (req) => {
        window.__calls.push({fn:'suggest', input:req.input, token:req.sessionToken && req.sessionToken.n});
        return { suggestions: [ { placePrediction: {
          placeId: 'p1', text:{text:'A, B', matches:[{startOffset:0,endOffset:1}]},
          mainText:{text:'A'}, secondaryText:{text:'B'}, types:['x'],
          toPlace(){ const p = new Place({id:'p1'}); p.viaPrediction = true; p.token = req.sessionToken; return p; } } } ] };
      } },
    }) } };
  ''';
  web.document.head!.append(script);
}

void main() {
  setUpAll(installStub);

  test('prediction + fetch in one session uses toPlace() and the same token', () async {
    final platform = FlPlaceAutocompleteWeb();
    final preds = await platform.findPredictions('pi', sessionId: 's', options: PredictionOptions());
    expect(preds.single.placeId, 'p1');
    await platform.findPredictions('piz', sessionId: 's', options: PredictionOptions());
    final place = await platform.fetchPlace('p1', sessionId: 's', fields: {PlaceField.location});
    expect(place.location, const LatLng(1, 2));
    final calls = (web.window as JSObject).getProperty<JSArray<JSObject>>('__calls'.toJS).toDart;
    final tokens = calls.map((c) => c.getProperty<JSAny?>('token'.toJS)?.dartify()).whereType<num>().toSet();
    expect(tokens.length, 1);
    final fetch = calls.last;
    expect(fetch.getProperty<JSBoolean>('viaPrediction'.toJS).toDart, isTrue);
  });

  test('without a cached prediction it falls back to a bare Place and warns', () async {
    final platform = FlPlaceAutocompleteWeb();
    final place = await platform.fetchPlace('unknown', fields: {PlaceField.id});
    expect(place.id, 'unknown');
  });

  test('disposeSession drops cached state', () async {
    final platform = FlPlaceAutocompleteWeb();
    await platform.findPredictions('pi', sessionId: 'd', options: PredictionOptions());
    await platform.disposeSession('d');
    final place = await platform.fetchPlace('p1', sessionId: 'd', fields: {PlaceField.id});
    expect(place.id, 'p1'); // fell back to bare Place
  });
}
```
Run `flutter test --platform chrome test/web_platform_test.dart` → FAIL.

- [ ] **Step 3: Implement `js_places.dart`** (dynamic JS access helpers, no static `@JS` names needed):

```dart
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Loads (once) and returns the `places` library object.
Future<JSObject> loadPlacesLibrary() async {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  final maps = google?.getProperty<JSObject?>('maps'.toJS);
  if (maps == null) {
    throw StateError('Google Maps JS API not found. Add the Maps JavaScript API <script> tag with your key to web/index.html.');
  }
  return await maps.callMethod<JSPromise<JSObject>>('importLibrary'.toJS, 'places'.toJS).toDart;
}

/// Reads [key] from [o] as a Dart value (strings, numbers, lists, maps).
Object? dartProp(JSObject o, String key) => o.getProperty<JSAny?>(key.toJS).dartify();

/// Reads [key] as a JS object.
JSObject? objProp(JSObject o, String key) => o.getProperty<JSObject?>(key.toJS);

/// Converts a Dart map/list tree to a JS object.
JSObject jsObject(Map<String, Object?> map) => map.jsify()! as JSObject;
```
`fl_place_autocomplete_web.dart`:

```dart
import 'dart:developer' as developer;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/js_places.dart';
import 'src/session_cache.dart';
import 'src/web_mapping.dart';

/// Web implementation using the Maps JavaScript API Places (New) library.
class FlPlaceAutocompleteWeb extends FlPlaceAutocompletePlatform {
  /// Registers this implementation.
  static void registerWith(Registrar registrar) {
    FlPlaceAutocompletePlatform.instance = FlPlaceAutocompleteWeb();
  }

  JSObject? _lib;
  SessionCache<JSObject, JSObject>? _sessions;
  final Map<String, JSObject> _photos = {};

  Future<JSObject> _library() async {
    try {
      final lib = _lib ??= await loadPlacesLibrary();
      _sessions ??= SessionCache<JSObject, JSObject>(
        () => (lib.getProperty<JSFunction>('AutocompleteSessionToken'.toJS)).callAsConstructor<JSObject>(),
      );
      return lib;
    } on StateError catch (e) {
      throw PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.invalidApiKey, message: e.message);
    } catch (e) {
      throw webError(e);
    }
  }

  @override
  Future<List<PlacePrediction>> findPredictions(String input, {String? sessionId, required PredictionOptions options}) async {
    final lib = await _library();
    try {
      final request = requestFromOptions(input, options);
      final js = jsObject(request);
      if (sessionId != null) js.setProperty('sessionToken'.toJS, _sessions!.entry(sessionId).token);
      final cls = lib.getProperty<JSObject>('AutocompleteSuggestion'.toJS);
      final result = await cls.callMethod<JSPromise<JSObject>>('fetchAutocompleteSuggestions'.toJS, js).toDart;
      final suggestions = result.getProperty<JSArray<JSObject>>('suggestions'.toJS).toDart;
      final out = <PlacePrediction>[];
      for (final s in suggestions) {
        final p = s.getProperty<JSObject>('placePrediction'.toJS);
        final json = <String, Object?>{
          'placeId': dartProp(p, 'placeId'),
          'text': _text(p, 'text'),
          'mainText': _text(p, 'mainText'),
          'secondaryText': _text(p, 'secondaryText'),
          'types': dartProp(p, 'types'),
          'distanceMeters': dartProp(p, 'distanceMeters'),
          'matches': _matches(p, 'text'),
        };
        final prediction = predictionFromWeb(json);
        if (sessionId != null) _sessions!.cachePrediction(sessionId, prediction.placeId, p);
        out.add(prediction);
      }
      return out;
    } catch (e) {
      throw webError(e);
    }
  }

  String? _text(JSObject p, String key) {
    final t = objProp(p, key);
    return t == null ? null : dartProp(t, 'text') as String?;
  }

  List<Map<String, Object?>> _matches(JSObject p, String key) {
    final t = objProp(p, key);
    final raw = t == null ? null : dartProp(t, 'matches');
    if (raw is! List) return const [];
    return [for (final m in raw) {'startOffset': (m as Map)['startOffset'], 'endOffset': m['endOffset']}];
  }

  @override
  Future<Place> fetchPlace(String placeId, {String? sessionId, required Set<PlaceField> fields, String? languageCode, String? regionCode}) async {
    final lib = await _library();
    try {
      JSObject? place;
      final cached = sessionId == null ? null : _sessions!.prediction(sessionId, placeId);
      if (cached != null) {
        place = cached.callMethod<JSObject>('toPlace'.toJS); // carries the session token
      } else {
        if (sessionId != null) {
          developer.log('No cached prediction for $placeId in session $sessionId; fetching outside the session (billed separately).', name: 'fl_place_autocomplete');
        }
        final init = <String, Object?>{'id': placeId, if (languageCode != null) 'requestedLanguage': languageCode, if (regionCode != null) 'requestedRegion': regionCode};
        place = lib.getProperty<JSFunction>('Place'.toJS).callAsConstructor<JSObject>(jsObject(init));
      }
      final opts = jsObject({'fields': fields.map((f) => f.apiName).toList()});
      await place.callMethod<JSPromise<JSAny?>>('fetchFields'.toJS, opts).toDart;
      final json = place.callMethod<JSObject>('toJSON'.toJS).dartify()! as Map<Object?, Object?>;
      if (sessionId != null) _sessions!.remove(sessionId); // fetchFields concludes the session
      final photos = place.getProperty<JSAny?>('photos'.toJS);
      return placeFromWebJson(json, photoIdFor: (i) {
        final id = '$placeId#$i';
        if (photos != null) _photos[id] = (photos as JSArray<JSObject>).toDart[i];
        return id;
      });
    } catch (e) {
      throw webError(e);
    }
  }

  @override
  Future<PhotoData> fetchPhoto(PlacePhotoRef ref, {int? maxWidth, int? maxHeight}) async {
    final photo = _photos[ref.id];
    if (photo == null) {
      throw const PlaceAutocompleteException(code: PlaceAutocompleteErrorCode.notFound, message: 'Unknown photo id; fetch the place again.');
    }
    final opts = jsObject({if (maxWidth != null) 'maxWidth': maxWidth, if (maxHeight != null) 'maxHeight': maxHeight});
    final uri = photo.callMethod<JSString>('getURI'.toJS, opts).toDart;
    return PhotoData(uri: uri);
  }

  @override
  Future<void> disposeSession(String sessionId) async => _sessions?.remove(sessionId);
}
```
Note the failure semantics: `_sessions.remove` runs only after `fetchFields` succeeds, so a failed fetch keeps the cached predictions (retry works). Adjust the stub test accordingly if `fetchFields` rejects.

- [ ] **Step 4: Run** `flutter test --platform chrome` → PASS. If the JS `Place.toJSON()` shape differs from the mapping (check in the example app in Task 13 against the live API), update `placeFromWebJson` and its test fixture together.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(web): JS interop platform with prediction cache for session tokens"
```

---

### Task 12: iOS implementation (SwiftPM only)

**Files:**
- Create/Modify under `fl_place_autocomplete_ios/`: `pubspec.yaml`, `lib/fl_place_autocomplete_ios.dart`, `test/registration_test.dart`, `ios/fl_place_autocomplete_ios/Package.swift`, `ios/fl_place_autocomplete_ios/Sources/FlPlaceAutocompleteCore/{SessionStore,ErrorMapper,Ranges}.swift`, `ios/fl_place_autocomplete_ios/Tests/FlPlaceAutocompleteCoreTests/CoreTests.swift`, `ios/fl_place_autocomplete_ios/Sources/fl_place_autocomplete_ios/{FlPlaceAutocompleteIosPlugin,PlaceMapping}.swift`
- Generated (Task 5): `Messages.g.swift` in the plugin target
- Delete: any `*.podspec`

**Interfaces:**
- Consumes: Pigeon Swift `PlacesHostApi` protocol (completion-based async methods) and `PlacesHostApiSetup.setUp(binaryMessenger:api:)`.
- Produces: `FlPlaceAutocompleteIos.registerWith()` in Dart; a pure-Swift `FlPlaceAutocompleteCore` target (testable with `swift test` on macOS).

- [ ] **Step 1: Dart side.** `pubspec.yaml`:

```yaml
flutter:
  plugin:
    implements: fl_place_autocomplete
    platforms:
      ios:
        pluginClass: FlPlaceAutocompleteIosPlugin
        dartPluginClass: FlPlaceAutocompleteIos
```
`lib/fl_place_autocomplete_ios.dart` and `test/registration_test.dart` mirror Task 9 Step 1 with names `FlPlaceAutocompleteIos` / `fl_place_autocomplete_ios`. Run `flutter test` → PASS after implementing.

- [ ] **Step 2: `Package.swift`** (the plugin must expose a library product named `fl-place-autocomplete-ios`; check the Flutter plugin SwiftPM docs/generated template for the exact product naming and `FlutterFramework` dependency form and keep them):

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fl_place_autocomplete_ios",
    platforms: [.iOS("16.0")],
    products: [
        .library(name: "fl-place-autocomplete-ios", targets: ["fl_place_autocomplete_ios"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/googlemaps/ios-places-sdk", from: "11.2.0"),
    ],
    targets: [
        .target(name: "FlPlaceAutocompleteCore"),
        .target(
            name: "fl_place_autocomplete_ios",
            dependencies: [
                "FlPlaceAutocompleteCore",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "GooglePlaces", package: "ios-places-sdk"),
            ]
        ),
        .testTarget(name: "FlPlaceAutocompleteCoreTests", dependencies: ["FlPlaceAutocompleteCore"]),
    ]
)
```
`from: "11.2.0"` is the latest release tag of the SDK repository (checked with `git ls-remote --tags` on 2026-10-08; its `Package.swift` declares iOS 16 and the `GooglePlaces` product). Re-check for a newer tag before implementing, and confirm the `GMSAutocompleteRequest`/`GMSFetchPlaceRequest` signatures against the 11.x reference. Make sure no `.podspec` exists: `find fl_place_autocomplete_ios -name '*.podspec'` prints nothing.

- [ ] **Step 3: Failing Swift core tests** (`Tests/FlPlaceAutocompleteCoreTests/CoreTests.swift`)

```swift
import XCTest
@testable import FlPlaceAutocompleteCore

final class CoreTests: XCTestCase {
    func testSessionStoreReusesAndRemoves() {
        var n = 0
        let store = SessionStore<String> { n += 1; return "t\(n)" }
        let a = store.getOrCreate("a")
        XCTAssertEqual(a, store.getOrCreate("a"))
        store.remove("a")
        XCTAssertNotEqual(a, store.getOrCreate("a"))
        XCTAssertNil(store.getOrNil(nil))
    }

    func testErrorCodes() {
        XCTAssertEqual(ErrorMapper.code(forMessage: "API key not valid"), "invalidApiKey")
        XCTAssertEqual(ErrorMapper.code(forMessage: "Quota exceeded"), "quotaExceeded")
        XCTAssertEqual(ErrorMapper.code(forMessage: "The Internet connection appears to be offline"), "networkError")
        XCTAssertEqual(ErrorMapper.code(forMessage: "not found"), "notFound")
        XCTAssertEqual(ErrorMapper.code(forMessage: "invalid argument"), "invalidRequest")
        XCTAssertEqual(ErrorMapper.code(forMessage: "boom"), "unknown")
    }

    func testRangesUseUTF16Offsets() {
        let s = "🍕 Pizza"
        let attributed = NSMutableAttributedString(string: s)
        let key = NSAttributedString.Key("matched")
        attributed.addAttribute(key, value: 1, range: NSRange(location: 3, length: 5))
        let ranges = Ranges.matched(in: attributed, attribute: key)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].0, 3)
        XCTAssertEqual(ranges[0].1, 8) // end offset in UTF-16 units, not Character count
        XCTAssertEqual(s.count, 7)     // Swift Character count differs: confirms we must not use it
    }
}
```
Run: `cd fl_place_autocomplete_ios/ios/fl_place_autocomplete_ios && swift test --filter FlPlaceAutocompleteCoreTests` — expected FAIL. (If `swift test` tries to resolve the iOS-only plugin target and fails, add `#if` guards or put the Core target in its own `Package.swift`-visible product and run `swift test` with `--package-path`; the Core target itself must have no dependencies.)

- [ ] **Step 4: Implement Core**

```swift
// SessionStore.swift
import Foundation

public final class SessionStore<T> {
    private var tokens: [String: T] = [:]
    private let lock = NSLock()
    private let make: () -> T
    public init(make: @escaping () -> T) { self.make = make }
    public func getOrCreate(_ id: String) -> T {
        lock.lock(); defer { lock.unlock() }
        if let t = tokens[id] { return t }
        let t = make(); tokens[id] = t; return t
    }
    public func getOrNil(_ id: String?) -> T? { id.map(getOrCreate) }
    public func remove(_ id: String) { lock.lock(); tokens[id] = nil; lock.unlock() }
}
```
```swift
// ErrorMapper.swift
import Foundation

public enum ErrorMapper {
    public static func code(forMessage message: String) -> String {
        let m = message.lowercased()
        if m.contains("api key") || m.contains("apikey") || m.contains("request denied") { return "invalidApiKey" }
        if m.contains("quota") || m.contains("over query") { return "quotaExceeded" }
        if m.contains("internet") || m.contains("network") || m.contains("offline") { return "networkError" }
        if m.contains("not found") { return "notFound" }
        if m.contains("invalid") { return "invalidRequest" }
        return "unknown"
    }
}
```
```swift
// Ranges.swift
import Foundation

public enum Ranges {
    /// (start, end) in UTF-16 code units, which matches Dart String indices.
    public static func matched(in text: NSAttributedString, attribute: NSAttributedString.Key) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        text.enumerateAttribute(attribute, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value != nil { out.append((range.location, range.location + range.length)) }
        }
        return out
    }
}
```
Run the Swift tests → PASS.

- [ ] **Step 5: Implement the plugin** `FlPlaceAutocompleteIosPlugin.swift`:

```swift
import Flutter
import GooglePlaces
import FlPlaceAutocompleteCore

public final class FlPlaceAutocompleteIosPlugin: NSObject, FlutterPlugin, PlacesHostApi {
    private let sessions = SessionStore<GMSAutocompleteSessionToken> { GMSAutocompleteSessionToken() }
    private let photos = PhotoStore()
    private var configured = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlPlaceAutocompleteIosPlugin()
        PlacesHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    }

    private func configure() throws {
        if configured { return }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSPlacesAPIKey") as? String, !key.isEmpty else {
            throw PigeonError(code: "invalidApiKey", message: "Missing GMSPlacesAPIKey in Info.plist", details: nil)
        }
        GMSPlacesClient.provideAPIKey(key)
        configured = true
    }

    private func fail(_ error: Error) -> PigeonError {
        if let e = error as? PigeonError { return e }
        return PigeonError(code: ErrorMapper.code(forMessage: error.localizedDescription), message: error.localizedDescription, details: nil)
    }

    func initialize(completion: @escaping (Result<Void, Error>) -> Void) {
        do { try configure(); completion(.success(())) } catch { completion(.failure(fail(error))) }
    }

    func disposeSession(sessionId: String) throws { sessions.remove(sessionId) }

    func findPredictions(input: String, sessionId: String?, options: OptionsMsg, completion: @escaping (Result<[PredictionMsg], Error>) -> Void) {
        do {
            try configure()
            let request = GMSAutocompleteRequest(query: input)
            request.sessionToken = sessions.getOrNil(sessionId)
            let filter = GMSAutocompleteFilter()
            if let bias = options.locationBias { filter.locationBias = bias.toBias() }
            if let r = options.locationRestriction { filter.locationRestriction = r.toRestriction() }
            if let o = options.origin { filter.origin = CLLocation(latitude: o.latitude, longitude: o.longitude) }
            if !options.includedPrimaryTypes.isEmpty { filter.types = options.includedPrimaryTypes.map { GMSPlaceType(rawValue: $0) } }
            if !options.includedRegionCodes.isEmpty { filter.countries = options.includedRegionCodes }
            if let region = options.regionCode { filter.regionCode = region }
            if let offset = options.inputOffset { request.inputOffset = Int(offset) }
            request.filter = filter
            GMSPlacesClient.shared().fetchAutocompleteSuggestions(from: request) { suggestions, error in
                if let error = error { completion(.failure(self.fail(error))); return }
                let out = (suggestions ?? []).compactMap { $0.placeSuggestion?.toMsg() }
                completion(.success(out))
            }
        } catch { completion(.failure(fail(error))) }
    }

    func fetchPlace(placeId: String, sessionId: String?, fields: [String], languageCode: String?, regionCode: String?, completion: @escaping (Result<PlaceMsg, Error>) -> Void) {
        do {
            try configure()
            let properties = fields.compactMap { propertyFor($0) }
            let request = GMSFetchPlaceRequest(placeID: placeId, placeProperties: properties.map { $0.rawValue }, sessionToken: sessions.getOrNil(sessionId))
            if let region = regionCode { request.regionCode = region }
            GMSPlacesClient.shared().fetchPlace(with: request) { place, error in
                if let error = error { completion(.failure(self.fail(error))); return }   // session stays usable
                guard let place = place else { completion(.failure(PigeonError(code: "notFound", message: "Place not found", details: nil))); return }
                if let id = sessionId { self.sessions.remove(id) }                        // Place Details ends the session
                completion(.success(place.toMsg(requested: Set(fields), photos: self.photos)))
            }
        } catch { completion(.failure(fail(error))) }
    }

    func fetchPhoto(ref: PhotoRefMsg, maxWidth: Int64?, maxHeight: Int64?, completion: @escaping (Result<PhotoDataMsg, Error>) -> Void) {
        guard let metadata = photos.get(ref.id) else {
            completion(.failure(PigeonError(code: "notFound", message: "Unknown photo id; fetch the place again.", details: nil))); return
        }
        let size = CGSize(width: Double(maxWidth ?? 1024), height: Double(maxHeight ?? 1024))
        let request = GMSFetchPhotoRequest(photoMetadata: metadata, maxSize: size)
        GMSPlacesClient.shared().fetchPhoto(with: request) { image, error in
            if let error = error { completion(.failure(self.fail(error))); return }
            guard let data = image?.jpegData(compressionQuality: 0.9) else {
                completion(.failure(PigeonError(code: "unknown", message: "Photo had no data", details: nil))); return
            }
            completion(.success(PhotoDataMsg(bytes: FlutterStandardTypedData(bytes: data), uri: nil)))
        }
    }
}
```
`PlaceMapping.swift` provides: `AreaMsg.toBias()` (circle → `GMSPlaceCircularLocationOption(CLLocationCoordinate2D, radius)`, rectangle → `GMSPlaceRectangularLocationOption(northEast, southWest)`), `LatLngBoundsMsg.toRestriction()` (`GMSPlaceRectangularLocationOption`), `GMSAutocompletePlaceSuggestion.toMsg()` (uses `attributedFullText` with the `kGMSAutocompleteMatchAttribute` key and `Ranges.matched(in:attribute:)`, `attributedPrimaryText.string`, `attributedSecondaryText?.string ?? ""`, `types`, `distanceMeters`), `propertyFor(_ name: String) -> GMSPlaceProperty?` (a `switch` over the 23 names, e.g. `"displayName" -> .name`, `"formattedAddress" -> .formattedAddress`, `"location" -> .coordinate`, `"viewport" -> .viewport`, `"photos" -> .photos`, `"reviews" -> .reviews`, …), `GMSPlace.toMsg(requested:photos:)` (fills **only** requested fields; `priceLevel` `GMSPlacesPriceLevel` → `free|inexpensive|moderate|expensive|veryExpensive`; `businessStatus` → `operational|closedTemporarily|closedPermanently`; each `GMSPlacePhotoMetadata` stored via `photos.put` returning an id), and `final class PhotoStore` (lock-protected LRU, capacity 200).

- [ ] **Step 6: Build and fix.** Build the example app for iOS (`cd fl_place_autocomplete/example && flutter build ios --no-codesign --simulator` after Task 13). For every unresolved symbol, consult the Places SDK for iOS (New) reference and adjust `PlaceMapping.swift` / the plugin file (class names such as `GMSAutocompleteRequest`, `GMSFetchPlaceRequest`, `GMSPlaceProperty` and the exact initializer labels vary by SDK version; if the installed SDK is 10.x, update `Package.swift`'s `from:` accordingly and record the version in the README). **Do not change the Pigeon contract.** Confirm `PigeonError`/`FlutterError` naming against the generated `Messages.g.swift`.

- [ ] **Step 7: Run tests and commit**

Run: `flutter test` (Dart) and `swift test` (Core).
Expected: PASS.

```bash
git add -A && git commit -m "feat(ios): SwiftPM-only Places SDK (New) implementation"
```

---

### Task 13: Example app

**Files:**
- Create (via `flutter create`): `fl_place_autocomplete/example/`
- Modify: example `lib/main.dart`, `lib/keys.example.dart`, `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `web/index.html`, `integration_test/live_test.dart`
- Test: `fl_place_autocomplete/example/test/widget_test.dart`

**Interfaces:**
- Consumes: the public package API.
- Produces: runnable example with three tabs (Headless, Default field, Custom field) and a details view.

- [ ] **Step 1: Create the app**

```bash
cd fl_place_autocomplete && flutter create --platforms=android,ios,web --org com.mk7 example
```
Add `fl_place_autocomplete: {path: ../}` to the example's pubspec, `resolution: workspace` off for the example (examples are not workspace members; remove the entry from the workspace list if `flutter create` added it).

- [ ] **Step 2: Key placement (documented in README)** (superseded by Task 15: the example now passes the key with `--dart-define-from-file=env.json` and has no native key wiring)
  - Android: in `AndroidManifest.xml` inside `<application>`: `<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_ANDROID_KEY"/>` (read from a gitignored `local.properties` placeholder via `manifestPlaceholders`: `GOOGLE_API_KEY`).
  - iOS: in `Info.plist`: `<key>GMSPlacesAPIKey</key><string>$(GOOGLE_API_KEY)</string>` fed from a gitignored `ios/Flutter/Keys.xcconfig` included by `Debug.xcconfig` and `Release.xcconfig`.
  - Web: `web/index.html` script tag using the dynamic loader, with the key replaced from a gitignored `web/keys.js`.
  - Commit `*.example` templates only.

- [ ] **Step 3: `lib/main.dart`.** Three tabs:
  1. **Headless:** a `TextField` + `ListView` driven by `FlPlaceAutocomplete.instance.newSession()` / `findPredictions` / `fetchPlace`, showing `place.location`.
  2. **Default field:** `PlaceAutocompleteField(onPlaceSelected: (p) => setState(() => place = p), initialValue: 'Eiffel Tower, Paris')` + a `PlaceDetailsCard` listing displayName, address, `lat, lng`, types.
  3. **Custom field:** custom `fieldBuilder` (pill-shaped `TextField` with a clear button calling `controller.clear()`), `predictionBuilder` rendering matched text in the accent color with `distanceMeters`, custom `emptyBuilder` / `errorBuilder`, `footerBuilder`, `fields` set to all of `PlaceField.values`, `options: PredictionOptions(includedRegionCodes: ['us'])`.

- [ ] **Step 4: Smoke widget test** (`example/test/widget_test.dart`): pump `MyApp` with a registered `FakePlatform`-style fake and assert the three tabs render without exceptions.

- [ ] **Step 5: Opt-in live test** (`integration_test/live_test.dart`): skipped unless `--dart-define=LIVE=true`; types "Eiffel", expects at least one row, taps it, expects `Place.location != null`.

- [ ] **Step 6: Verify builds**

```bash
cd fl_place_autocomplete/example
flutter build web
flutter build apk --debug
flutter build ios --no-codesign --simulator
```
Expected: all three succeed (this is the first full native compile for Tasks 9 and 12; fix mapping compile errors there). Run the app on at least web or one emulator with a real key and confirm: predictions appear, selection returns coordinates, no request is sent for the initial value (check the network panel / logs).

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: example app with headless, default and custom field demos"
```

---

### Task 14: CI, docs, publishing metadata

**Files:**
- Create: `.github/workflows/ci.yml`, `README.md`, `fl_place_autocomplete/README.md`, `fl_place_autocomplete/CHANGELOG.md` (+ CHANGELOG/README per package), `docs/setup.md`, `docs/sessions-and-billing.md`
- Modify: each package `pubspec.yaml` (homepage, repository, topics, `issue_tracker`)

**Interfaces:**
- Produces: green CI; docs covering key setup, billing/session behaviour, attribution.

- [ ] **Step 1: CI workflow** (`.github/workflows/ci.yml`)

```yaml
name: ci
on: [push, pull_request]
jobs:
  dart:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: {channel: stable}
      - run: dart pub get
      - run: dart run melos run analyze
      - run: dart run melos run test
      - run: cd fl_place_autocomplete_web && flutter test --platform chrome
      - run: dart format --output=none --set-exit-if-changed .
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: {distribution: temurin, java-version: 17}
      - uses: subosito/flutter-action@v2
      - run: dart pub get
      - run: cd fl_place_autocomplete/example && flutter build apk --debug
  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter config --enable-swift-package-manager
      - run: dart pub get
      - run: cd fl_place_autocomplete_ios/ios/fl_place_autocomplete_ios && swift test --filter FlPlaceAutocompleteCoreTests
      - run: cd fl_place_autocomplete/example && flutter build ios --no-codesign --simulator
  web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: dart pub get
      - run: cd fl_place_autocomplete/example && flutter build web
```
Also add a check that Pigeon output is committed and up to date: run `dart run melos run generate` then `git diff --exit-code`.

- [ ] **Step 2: Docs.** `docs/setup.md`: per-platform key setup (AndroidManifest meta-data `com.google.android.geo.API_KEY`, Info.plist `GMSPlacesAPIKey`, `index.html` script with the Maps JS loader), enabling "Places API (New)" in Google Cloud, key restrictions, **iOS: SwiftPM required (Flutter >= 3.44; `flutter config --enable-swift-package-manager`), no CocoaPods support**. `docs/sessions-and-billing.md`: the session lifecycle from spec §4, what happens on failure/abandon, the web prediction-cache caveat, field billing tiers pointer, **verify and record Google's current session token expiry from the Places docs (not assumed in code)**. README attribution section: "Powered by Google" requirement and the `footerBuilder` opt-out being the app developer's responsibility.

- [ ] **Step 3: Final verification (superpowers:verification-before-completion)**

```bash
dart pub get
dart run melos run analyze
dart run melos run test
cd fl_place_autocomplete_web && flutter test --platform chrome && cd ..
(cd fl_place_autocomplete_ios/ios/fl_place_autocomplete_ios && swift test)
find fl_place_autocomplete_ios -name '*.podspec' | wc -l   # must print 0
(cd fl_place_autocomplete_platform_interface && dart run pigeon --input pigeons/messages.dart) && git diff --exit-code
for p in fl_place_autocomplete_platform_interface fl_place_autocomplete_android fl_place_autocomplete_ios fl_place_autocomplete_web fl_place_autocomplete; do (cd $p && flutter pub publish --dry-run); done
```
Expected: all green; podspec count 0; no Pigeon diff; dry-runs report no errors (warnings about unpublished sibling packages are acceptable until first publish).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "chore: CI, docs and publishing metadata"
```

---

## Self-Review (spec coverage)

| Spec section | Task |
|---|---|
| §2 packages / endorsed default_package | 1, 6, 9, 11, 12 |
| §3 headless API, `location` lat/lng, `PlacePrediction`, `Place`, exceptions, `fetchPhoto` | 2, 3, 4, 5, 6 |
| §4 session handling (Dart-owned, single-use, abandon, per-platform, web cache) | 4, 6, 7, 9, 10, 11, 12 |
| §5.1 widget parameters and builders | 8 |
| §5.2 widget behaviour (debounce, stale drop, session, blur, selection, controller, keyboard) | 7, 8 |
| §5.3 attribution footer | 8, 14 |
| §5.4 initial value rule | 7 (controller tests), 8 (widget tests), 13 (manual check) |
| §6 native key config | 9, 11, 12, 13, 14 |
| §7 Pigeon schema, Android, iOS SPM-only, web | 5, 9, 12, 10-11 |
| §8 testing (interface, lifecycle, widget, native, web, opt-in live) | 2-12, 13 |
| §9 example app, repo, CI, docs | 13, 14 |
| §10 Milestone 2 | out of scope for this plan (separate plan) |

Spec §7 "to verify" items are resolved as decisions in this plan: Android key via manifest meta-data `com.google.android.geo.API_KEY`; iOS key `GMSPlacesAPIKey`; restriction is rectangle-only, bias is circle or rectangle on all platforms; iOS SDK pinned from `11.2.0` (latest tag when checked) with a re-check step; session expiry is documented from Google's docs in Task 14 rather than hard-coded.


---

### Task 15: `--dart-define` API key injection (added 2026-10-08, user request; supersedes the "No API key in Dart" constraint)

**Files:**
- Modify: `fl_place_autocomplete_platform_interface/pigeons/messages.dart` (`initialize` gets `String? apiKey`) and regenerate `messages.g.dart`, Kotlin `Messages.g.kt`, Swift `Messages.g.swift`
- Create: `fl_place_autocomplete_platform_interface/lib/src/api_key.dart` (`PlacesApiKey`)
- Modify: `fl_place_autocomplete_platform_interface/lib/src/pigeon/pigeon_platform.dart` (+ barrel export of `PlacesApiKey`)
- Modify: Android `FlPlaceAutocompleteAndroidPlugin.kt`; iOS `FlPlaceAutocompleteIosPlugin.swift` (+ Core `KeyResolver`); Web `fl_place_autocomplete_web.dart`, `src/js_places.dart`
- Modify: example app (remove native key wiring, use dart-define), docs, READMEs, spec/plan constraints text
- Test: platform_interface `test/api_key_test.dart`, `test/pigeon_platform_test.dart`; Kotlin `KeyResolverTest`; Swift Core `KeyResolverTests`; web `test/loader_test.dart`

**Interfaces:**
- Produces: `abstract final class PlacesApiKey { static String? resolve({required PlacesApiPlatform platform, String generic, Map<PlacesApiPlatform,String> perPlatform}) }` is NOT required; use this shape:
  - `enum PlacesApiPlatform { android, ios, web }`
  - `String? resolvePlacesApiKey({required PlacesApiPlatform platform, String generic = _genericKey, String? android = _androidKey, String? ios = _iosKey, String? web = _webKey})` where the private constants are `const String.fromEnvironment('GOOGLE_PLACES_API_KEY')`, `..._ANDROID`, `..._IOS`, `..._WEB`; returns the platform-specific value if non-blank, else the generic one if non-blank, else `null`. The default arguments are the compile-time defines; tests pass explicit values.
  - `PigeonPlacesPlatform({PlacesHostApi? api, String? apiKey, PlacesApiPlatform? platform})`: before the first `findPredictions`/`fetchPlace`/`fetchPhoto` it awaits a memoized `_ensureInitialized()` = `_api.initialize(apiKey ?? resolvePlacesApiKey(platform: platform ?? currentPlatform))`; if initialize throws the memo is cleared so the next call retries. `disposeSession` does not trigger initialize.
  - Pigeon: `@async void initialize(String? apiKey);` (Kotlin `suspend fun initialize(apiKey: String?)`, Swift `func initialize(apiKey: String?) async throws`).
  - Kotlin/Swift pure helper `KeyResolver.pick(explicit: String?, fallback: String?): String?` returns the first non-blank (trimmed) value.
- Consumes: Task 5 platform, Task 9 Android plugin, Task 11 web, Task 12 iOS plugin, Task 13 example.

- [ ] **Step 1: Failing tests (Dart).** `api_key_test.dart`: platform-specific beats generic; blank/whitespace ignored; generic used when specific blank; `null` when neither; each of android/ios/web selects its own override. `pigeon_platform_test.dart`: first `findPredictions` calls `initialize(apiKey)` exactly once with the injected key; a second call does not call it again; `initialize` failure (`PlatformException(invalidApiKey)`) surfaces as `PlaceAutocompleteException` and the NEXT call retries initialize; concurrent first calls share one initialize; `disposeSession` never calls initialize.
- [ ] **Step 2: Run, see FAIL; implement `api_key.dart`, update the Pigeon schema, regenerate (`dart run melos run generate`), update `PigeonPlacesPlatform` (current platform from `defaultTargetPlatform`: android->android, iOS->ios; anything else -> treated as `android` is WRONG, so for other platforms use the generic key only), run tests -> PASS.** Update the existing mock `_Api` in tests to the new `initialize(String? apiKey)` signature.
- [ ] **Step 3: Android.** `KeyResolver` (pure Kotlin, unit-tested first) and use it in `client()`: `KeyResolver.pick(apiKey, manifestMetaData)`; blank -> `FlutterError("invalidApiKey", "No API key. Pass --dart-define=GOOGLE_PLACES_API_KEY[_ANDROID]=... or add com.google.android.geo.API_KEY meta-data to AndroidManifest.xml")`. `initialize(apiKey)` stores/uses it; `findPredictions`/`fetchPlace`/`fetchPhoto` still call the same lazy `client()` (Dart has already sent `initialize` first). If Places is already initialized, reuse (existing behaviour). Keep suspend signatures from the regenerated file.
- [ ] **Step 4: iOS.** Mirror in Swift Core (`KeyResolver.pick` + XCTest first). In the plugin: `@MainActor` key provisioning uses `KeyResolver.pick(apiKey, Bundle.main GMSPlacesAPIKey)`; same error message. The provide-once flag stays main-actor guarded; if an explicit key arrives after a plist key was already provided, the SDK keeps the first (document).
- [ ] **Step 5: Web.** Pure `String buildLoaderSource(String apiKey, {String version = 'weekly'})` returning Google's documented inline dynamic-loader bootstrap JS with the key embedded via a JSON-encoded string literal (no injection through quotes; test with a key containing `"` and `\\`). `loadPlacesLibrary(String? apiKey)`: if `google.maps.importLibrary` is missing and `apiKey` non-blank, append a `<script>` with that source to `document.head` (once) and then proceed; if still missing -> `MapsApiMissing` with the message listing all three options. If `google.maps` already exists never inject. The web platform resolves its key via `resolvePlacesApiKey(platform: web)` at construction (injectable for tests). Chrome tests: injects exactly one script when absent and key given; no injection when `google.maps` present; no key + no maps -> `invalidApiKey` with the three-option message.
- [ ] **Step 6: Example app.** Remove the native key wiring from the example (Android `manifestPlaceholders`/meta-data/`local.properties.example`, iOS `Keys.xcconfig*`/Info.plist `GMSPlacesAPIKey`, web `keys.js*` + the index.html bootstrap) and the related .gitignore entries; add `example/env.example.json` (`{"GOOGLE_PLACES_API_KEY": ""}`) and gitignore `example/env.json`. The app shows a banner when `const String.fromEnvironment('GOOGLE_PLACES_API_KEY')` is empty (and no platform-specific one) telling the user to run `flutter run --dart-define-from-file=env.json`. Smoke test + live test updated; builds must still pass with NO key (web, apk, ios simulator).
- [ ] **Step 7: Docs.** Update `docs/setup.md`, root + per-package READMEs, CHANGELOGs: dart-define usage (`flutter run --dart-define=GOOGLE_PLACES_API_KEY=...`, per-platform overrides, `--dart-define-from-file`), precedence, native fallback, that dart-define values are compiled into the app binary (not secret; use platform key restrictions: package name + SHA-1, bundle id, HTTP referrer), CI snippet. Remove statements that "no key in Dart".
- [ ] **Step 8: Verification.** `dart pub get`; `dart run melos run analyze`; `dart run melos run test`; web chrome tests; `fl_place_autocomplete_ios/tool/test_core.sh`; Kotlin unit tests in a throwaway app; `dart run melos run generate && git diff --exit-code` (generated files committed); example builds (web/apk/ios sim) with and without `--dart-define=GOOGLE_PLACES_API_KEY=dummy`; podspec count 0.
- [ ] **Step 9: Commit** (no attribution trailer): `git commit -m "feat: --dart-define API key injection with native fallback"`.
