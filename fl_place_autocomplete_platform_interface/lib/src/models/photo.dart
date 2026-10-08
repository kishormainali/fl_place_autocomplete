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
  const PlacePhotoRef({
    required this.id,
    this.widthPx,
    this.heightPx,
    this.authorAttributions = const [],
  });

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
