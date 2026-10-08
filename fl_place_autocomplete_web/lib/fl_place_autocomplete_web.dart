import 'dart:developer' as developer;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/js_places.dart';
import 'src/session_cache.dart';
import 'src/web_mapping.dart';

/// Web implementation using the Maps JavaScript API Places (New) library.
///
/// Session tokens are kept per Dart session id. Only
/// `placePrediction.toPlace()` carries the session token into `fetchFields`,
/// so the original JS prediction objects are cached by place id.
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
        () => construct(lib, 'AutocompleteSessionToken'),
      );
      return lib;
    } on MapsApiMissing catch (e) {
      throw PlaceAutocompleteException(
        code: PlaceAutocompleteErrorCode.invalidApiKey,
        message: e.message,
      );
    } catch (e) {
      throw webError(e);
    }
  }

  @override
  Future<List<PlacePrediction>> findPredictions(
    String input, {
    String? sessionId,
    required PredictionOptions options,
  }) async {
    final lib = await _library();
    try {
      final request = jsObject(requestFromOptions(input, options));
      if (sessionId != null) {
        request.setProperty(
          'sessionToken'.toJS,
          _sessions!.entry(sessionId).token,
        );
      }
      final suggestion = lib.getProperty<JSObject>(
        'AutocompleteSuggestion'.toJS,
      );
      final result = await suggestion
          .callMethod<JSPromise<JSObject>>(
            'fetchAutocompleteSuggestions'.toJS,
            request,
          )
          .toDart;
      final out = <PlacePrediction>[];
      for (final s in arrayProp(result, 'suggestions') ?? const <JSObject>[]) {
        final p = objProp(s, 'placePrediction');
        if (p == null) continue;
        final prediction = predictionFromWeb({
          'placeId': dartProp(p, 'placeId'),
          'text': _text(p, 'text'),
          'mainText': _text(p, 'mainText'),
          'secondaryText': _text(p, 'secondaryText'),
          'types': dartProp(p, 'types'),
          'distanceMeters': dartProp(p, 'distanceMeters'),
          'matches': _matches(p, 'text'),
        });
        if (sessionId != null) {
          _sessions!.cachePrediction(sessionId, prediction.placeId, p);
        }
        out.add(prediction);
      }
      return out;
    } catch (e) {
      throw webError(e);
    }
  }

  String? _text(JSObject p, String key) {
    final t = objProp(p, key);
    final text = t == null ? null : dartProp(t, 'text');
    return text is String ? text : null;
  }

  // Reads each match through property access: the real API returns
  // `StringRange` instances, whose fields need not be own enumerable
  // properties (which is all `dartify()` copies).
  List<Map<String, Object?>> _matches(JSObject p, String key) {
    final t = objProp(p, key);
    final raw = t == null ? null : arrayProp(t, 'matches');
    return [
      for (final m in raw ?? const <JSObject>[])
        {
          'startOffset': dartProp(m, 'startOffset'),
          'endOffset': dartProp(m, 'endOffset'),
        },
    ];
  }

  @override
  Future<Place> fetchPlace(
    String placeId, {
    String? sessionId,
    required Set<PlaceField> fields,
    String? languageCode,
    String? regionCode,
  }) async {
    final lib = await _library();
    try {
      final cached = sessionId == null
          ? null
          : _sessions!.prediction(sessionId, placeId);
      final JSObject place;
      if (cached != null) {
        // toPlace() carries the session token into fetchFields.
        place = cached.callMethod<JSObject>('toPlace'.toJS);
      } else {
        if (sessionId != null) {
          developer.log(
            'No cached prediction for $placeId in session $sessionId; '
            'fetching outside the session (billed separately).',
            name: 'fl_place_autocomplete',
            level: 900,
          );
        }
        place = construct(
          lib,
          'Place',
          jsObject({
            'id': placeId,
            'requestedLanguage': ?languageCode,
            'requestedRegion': ?regionCode,
          }),
        );
      }
      await place
          .callMethod<JSPromise<JSAny?>>(
            'fetchFields'.toJS,
            jsObject({
              'fields': [for (final f in fields) f.apiName],
            }),
          )
          .toDart;
      // Only a successful fetch concludes the session; a failed one keeps the
      // cached predictions so a retry still carries the token.
      if (sessionId != null) _sessions!.remove(sessionId);
      final json =
          place.callMethod<JSObject>('toJSON'.toJS).dartify()!
              as Map<Object?, Object?>;
      final photos = arrayProp(place, 'photos');
      return placeFromWebJson(
        json,
        photoIdFor: (i) {
          final id = '$placeId#$i';
          if (photos != null && i < photos.length) _photos[id] = photos[i];
          return id;
        },
      );
    } catch (e) {
      throw webError(e);
    }
  }

  @override
  Future<PhotoData> fetchPhoto(
    PlacePhotoRef ref, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    final photo = _photos[ref.id];
    if (photo == null) {
      throw const PlaceAutocompleteException(
        code: PlaceAutocompleteErrorCode.notFound,
        message: 'Unknown photo id; fetch the place again.',
      );
    }
    try {
      final uri = photo
          .callMethod<JSString>(
            'getURI'.toJS,
            jsObject({'maxWidth': ?maxWidth, 'maxHeight': ?maxHeight}),
          )
          .toDart;
      return PhotoData(uri: uri);
    } catch (e) {
      throw webError(e);
    }
  }

  @override
  Future<void> disposeSession(String sessionId) async =>
      _sessions?.remove(sessionId);
}
