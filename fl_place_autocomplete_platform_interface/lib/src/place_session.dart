import 'dart:math';

import 'exceptions.dart';

/// A single-use autocomplete session. Created in Dart; native sides lazily
/// map [id] to their real session token.
class PlaceSession {
  /// Wraps an explicit [id] (useful in tests).
  PlaceSession.withId(this.id);

  /// Creates a session with a random 128-bit id.
  factory PlaceSession.create() {
    final r = Random.secure();
    final id = List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return PlaceSession.withId(id);
  }

  /// Opaque id shared with the platform implementation.
  final String id;
  bool _ended = false;

  /// Whether the session has ended (a place was fetched or it was cancelled).
  bool get isEnded => _ended;

  /// Marks the session ended. Safe to call repeatedly.
  void end() => _ended = true;

  /// Throws a [PlaceAutocompleteException] with
  /// [PlaceAutocompleteErrorCode.sessionEnded] if the session has ended.
  void ensureActive() {
    if (_ended) {
      throw PlaceAutocompleteException(
        code: PlaceAutocompleteErrorCode.sessionEnded,
        message:
            'PlaceSession $id has ended; create a new session with newSession().',
      );
    }
  }
}
