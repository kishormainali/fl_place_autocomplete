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
