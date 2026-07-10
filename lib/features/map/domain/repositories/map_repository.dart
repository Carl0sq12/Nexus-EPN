/// Represents a geographic point with latitude and longitude.
class MapPoint {
  final double latitude;
  final double longitude;

  const MapPoint({required this.latitude, required this.longitude});
}

/// Abstract repository for map-related operations.
abstract class MapRepository {
  /// Returns the current device location as a [MapPoint].
  Future<MapPoint> getCurrentLocation();
}
