import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Route geometry and travel metrics between two selected map points.
class RouteInfo extends Equatable {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  @override
  List<Object?> get props => [points, distanceMeters, durationSeconds];
}
