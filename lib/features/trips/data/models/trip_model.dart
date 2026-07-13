import '../../domain/entities/trip.dart';
import '../../../../core/constants/app_limits.dart';
import '../../../../core/utils/geo_fare.dart';
import 'package:latlong2/latlong.dart';

/// Data model for [Trip] with JSON serialization using Supabase snake_case keys.
class TripModel extends Trip {
  const TripModel({
    required String id,
    required String driverId,
    required String origin,
    required String destination,
    required DateTime departureTime,
    required int totalSeats,
    required int availableSeats,
    required double pricePerSeat,
    required String status,
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    double? routeDistanceMeters,
    double? routeDurationSeconds,
    List<LatLng>? routePoints,
  }) : super(
         id: id,
         driverId: driverId,
         origin: origin,
         destination: destination,
         departureTime: departureTime,
         totalSeats: totalSeats,
         availableSeats: availableSeats,
         pricePerSeat: pricePerSeat,
         status: status,
         originLatitude: originLatitude,
         originLongitude: originLongitude,
         destinationLatitude: destinationLatitude,
         destinationLongitude: destinationLongitude,
         routeDistanceMeters: routeDistanceMeters,
         routeDurationSeconds: routeDurationSeconds,
         routePoints: routePoints,
       );

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final rawTotalSeats = (json['total_seats'] as num).toInt();
    final rawAvailableSeats = (json['available_seats'] as num).toInt();
    final occupiedSeats = (rawTotalSeats - rawAvailableSeats).clamp(
      0,
      rawTotalSeats,
    );
    final totalSeats = rawTotalSeats.clamp(1, AppLimits.maxTripSeats).toInt();
    final availableSeats = (totalSeats - occupiedSeats)
        .clamp(0, totalSeats)
        .toInt();

    return TripModel(
      id: (json['id'] ?? json[r'$id']) as String,
      driverId: json['driver_id'] as String,
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      departureTime: DateTime.parse(json['departure_time'] as String),
      totalSeats: totalSeats,
      availableSeats: availableSeats,
      pricePerSeat: (json['price_per_seat'] as num).toDouble(),
      status: json['status'] as String? ?? 'active',
      originLatitude: (json['origin_latitude'] as num?)?.toDouble(),
      originLongitude: (json['origin_longitude'] as num?)?.toDouble(),
      destinationLatitude: (json['destination_latitude'] as num?)?.toDouble(),
      destinationLongitude: (json['destination_longitude'] as num?)?.toDouble(),
      routeDistanceMeters: (json['route_distance_meters'] as num?)?.toDouble(),
      routeDurationSeconds: (json['route_duration_seconds'] as num?)
          ?.toDouble(),
      routePoints: json['route_points'] is String
          ? RouteGeometry.decodePoints(json['route_points'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'origin': origin,
      'destination': destination,
      'departure_time': departureTime.toIso8601String(),
      'total_seats': totalSeats,
      'available_seats': availableSeats,
      'price_per_seat': pricePerSeat,
      'status': status,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'route_distance_meters': routeDistanceMeters,
      'route_duration_seconds': routeDurationSeconds,
      if (routePoints != null)
        'route_points': RouteGeometry.encodePoints(routePoints!),
    };
  }
}
