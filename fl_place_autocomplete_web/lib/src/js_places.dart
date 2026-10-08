import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Thrown when `google.maps` (or its `importLibrary` loader) is not on the
/// page.
class MapsApiMissing implements Exception {
  /// Creates the error; [legacyLoader] marks a page whose `google.maps` lacks
  /// `importLibrary` (an old or incomplete loader).
  const MapsApiMissing({this.legacyLoader = false});

  /// Whether `google.maps` exists but `importLibrary` does not.
  final bool legacyLoader;

  /// Human readable setup hint.
  String get message => legacyLoader
      ? 'google.maps.importLibrary is not available: the page uses a legacy or '
            'incomplete Maps JavaScript API loader. Load the API with the '
            'dynamic library import bootstrap (or a <script> tag with '
            'loading=async) and your API key in web/index.html.'
      : 'Google Maps JavaScript API not found (window.google.maps is '
            'undefined). Add the Maps JavaScript API <script> tag with your '
            'API key to web/index.html.';

  @override
  String toString() => message;
}

/// Loads and returns the `places` library object.
///
/// Throws [MapsApiMissing] when `google.maps` or `google.maps.importLibrary`
/// is absent.
Future<JSObject> loadPlacesLibrary() async {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  final maps = google?.getProperty<JSObject?>('maps'.toJS);
  if (maps == null) throw const MapsApiMissing();
  if (!isFunction(maps, 'importLibrary')) {
    throw const MapsApiMissing(legacyLoader: true);
  }
  final JSPromise<JSObject> promise;
  try {
    promise = maps.callMethod<JSPromise<JSObject>>(
      'importLibrary'.toJS,
      'places'.toJS,
    );
  } on Object catch (e) {
    // e.g. "TypeError: importLibrary is not a function" from a broken loader.
    if ('$e'.contains('TypeError') || '$e'.contains('not a function')) {
      throw const MapsApiMissing(legacyLoader: true);
    }
    rethrow;
  }
  return promise.toDart;
}

/// Whether `o[key]` is a function.
bool isFunction(JSObject o, String key) =>
    o.getProperty<JSAny?>(key.toJS).typeofEquals('function');

/// Converts a JS value to Dart; a `Date` becomes its ISO-8601 string.
Object? _value(JSAny? v) {
  if (v == null || v.isUndefinedOrNull) return null;
  if (v.typeofEquals('object') && isFunction(v as JSObject, 'toISOString')) {
    return v.callMethod<JSString>('toISOString'.toJS).toDart;
  }
  final d = v.dartify();
  return d is DateTime ? d.toUtc().toIso8601String() : d;
}

Map<Object?, Object?>? _toJsonMap(JSObject o) {
  if (!isFunction(o, 'toJSON')) return null;
  final j = o.callMethod<JSAny?>('toJSON'.toJS).dartify();
  return j is Map ? j : null;
}

/// Reads [keys] from a JS object that may be a class instance whose fields
/// are prototype getters (which `dartify()` does not copy). Property reads
/// win; `toJSON()` output fills the gaps.
Map<Object?, Object?> _record(
  JSObject o,
  List<String> keys, [
  Map<Object?, Object?>? fallback,
]) {
  final json = _toJsonMap(o);
  return {
    for (final k in keys)
      k: _value(o.getProperty<JSAny?>(k.toJS)) ?? json?[k] ?? fallback?[k],
  };
}

const _authorKeys = ['displayName', 'uri', 'photoURI'];

/// `{lat, lng}` for a `LatLng` instance or literal, or null.
Map<String, Object?>? latLngJson(JSObject? o) {
  if (o == null) return null;
  Object? lat;
  Object? lng;
  if (isFunction(o, 'lat') && isFunction(o, 'lng')) {
    lat = o.callMethod<JSAny?>('lat'.toJS).dartify();
    lng = o.callMethod<JSAny?>('lng'.toJS).dartify();
  } else {
    final m = _toJsonMap(o) ?? _record(o, const ['lat', 'lng']);
    lat = m['lat'];
    lng = m['lng'];
  }
  return lat is num && lng is num ? {'lat': lat, 'lng': lng} : null;
}

/// `{south, west, north, east}` for a `LatLngBounds` instance or literal, or
/// null.
Map<String, Object?>? boundsJson(JSObject? o) {
  if (o == null) return null;
  if (isFunction(o, 'getSouthWest') && isFunction(o, 'getNorthEast')) {
    final sw = latLngJson(o.callMethod<JSObject?>('getSouthWest'.toJS));
    final ne = latLngJson(o.callMethod<JSObject?>('getNorthEast'.toJS));
    if (sw != null && ne != null) {
      return {
        'south': sw['lat'],
        'west': sw['lng'],
        'north': ne['lat'],
        'east': ne['lng'],
      };
    }
  }
  const keys = ['south', 'west', 'north', 'east'];
  final m = _toJsonMap(o) ?? _record(o, keys);
  return keys.every((k) => m[k] is num)
      ? {for (final k in keys) k: m[k]}
      : null;
}

/// Plain map for a `Photo` instance (sizes and author attributions).
///
/// [fallback] is the matching entry of the Place's own `toJSON()` output.
Map<Object?, Object?> photoJson(JSObject p, [Map<Object?, Object?>? fallback]) {
  final own = _toJsonMap(p);
  final out = _record(p, const ['widthPx', 'heightPx'], fallback);
  final authors = arrayProp(p, 'authorAttributions');
  out['authorAttributions'] = authors == null
      ? (own?['authorAttributions'] ?? fallback?['authorAttributions'])
      : [for (final a in authors) _record(a, _authorKeys)];
  return out;
}

/// Plain map for a `Review` instance; `publishTime` becomes ISO-8601 text.
///
/// [fallback] is the matching entry of the Place's own `toJSON()` output.
Map<Object?, Object?> reviewJson(
  JSObject r, [
  Map<Object?, Object?>? fallback,
]) {
  final own = _toJsonMap(r);
  final out = _record(r, const [
    'rating',
    'text',
    'relativePublishTimeDescription',
    'publishTime',
  ], fallback);
  final author = objProp(r, 'authorAttribution');
  out['authorAttribution'] = author == null
      ? (own?['authorAttribution'] ?? fallback?['authorAttribution'])
      : _record(author, _authorKeys);
  return out;
}

/// Reads [key] from [o] as a Dart value (strings, numbers, lists, maps).
Object? dartProp(JSObject o, String key) =>
    o.getProperty<JSAny?>(key.toJS).dartify();

/// Reads [key] as a JS object.
JSObject? objProp(JSObject o, String key) => o.getProperty<JSObject?>(key.toJS);

/// Reads [key] as a JS array of objects.
List<JSObject>? arrayProp(JSObject o, String key) =>
    o.getProperty<JSArray<JSObject>?>(key.toJS)?.toDart;

/// Converts a Dart map/list tree to a JS object.
JSObject jsObject(Map<String, Object?> map) => map.jsify()! as JSObject;

/// Constructs `new lib[className](...args)`.
JSObject construct(JSObject lib, String className, [JSAny? arg]) {
  final ctor = lib.getProperty<JSFunction>(className.toJS);
  return arg == null
      ? ctor.callAsConstructor<JSObject>()
      : ctor.callAsConstructor<JSObject>(arg);
}
