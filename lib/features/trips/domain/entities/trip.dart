import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Entity representing a trip published by a driver.
class Trip extends Equatable {
  final String id;
  final String driverId;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final int totalSeats;
  final int availableSeats;
  final double pricePerSeat;
  final String status;
  final double? originLatitude;
  final double? originLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final double? routeDistanceMeters;
  final double? routeDurationSeconds;
  final List<LatLng>? routePoints;

  const Trip({
    required this.id,
    required this.driverId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.status,
    this.originLatitude,
    this.originLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    this.routePoints,
  });

  @override
  List<Object?> get props => [
    id,
    driverId,
    origin,
    destination,
    departureTime,
    totalSeats,
    availableSeats,
    pricePerSeat,
    status,
    originLatitude,
    originLongitude,
    destinationLatitude,
    destinationLongitude,
    routeDistanceMeters,
    routeDurationSeconds,
    routePoints,
  ];
}
