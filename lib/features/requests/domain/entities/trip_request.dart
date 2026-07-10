import 'package:equatable/equatable.dart';

/// Entity representing a request to join a trip.
class TripRequest extends Equatable {
  final String id;
  final String tripId;
  final String passengerId;
  final String status;
  final int passengerCount;
  final String? pickupNote;
  final String? dropoffNote;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final List<TripRequestStop> stops;
  final double? proposedPrice;
  final String? priceNote;
  final DateTime createdAt;

  const TripRequest({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.status,
    this.passengerCount = 1,
    this.pickupNote,
    this.dropoffNote,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.stops = const [],
    this.proposedPrice,
    this.priceNote,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    tripId,
    passengerId,
    status,
    passengerCount,
    pickupNote,
    dropoffNote,
    pickupLatitude,
    pickupLongitude,
    dropoffLatitude,
    dropoffLongitude,
    stops,
    proposedPrice,
    priceNote,
    createdAt,
  ];
}

class TripRequestStop extends Equatable {
  final String label;
  final double latitude;
  final double longitude;

  const TripRequestStop({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [label, latitude, longitude];
}
