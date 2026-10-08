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
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

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
  bool operator ==(Object other) =>
      other is LatLngBounds &&
      other.southwest == southwest &&
      other.northeast == northeast;

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
