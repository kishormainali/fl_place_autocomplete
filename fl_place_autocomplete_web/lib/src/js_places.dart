import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Thrown when `google.maps` is not on the page.
class MapsApiMissing implements Exception {
  /// Creates the error.
  const MapsApiMissing();

  /// Human readable setup hint.
  String get message =>
      'Google Maps JavaScript API not found (window.google.maps is undefined). '
      'Add the Maps JavaScript API <script> tag with your API key to '
      'web/index.html.';

  @override
  String toString() => message;
}

/// Loads and returns the `places` library object.
///
/// Throws [MapsApiMissing] when `google.maps` is absent.
Future<JSObject> loadPlacesLibrary() async {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  final maps = google?.getProperty<JSObject?>('maps'.toJS);
  if (maps == null) throw const MapsApiMissing();
  return maps
      .callMethod<JSPromise<JSObject>>('importLibrary'.toJS, 'places'.toJS)
      .toDart;
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
