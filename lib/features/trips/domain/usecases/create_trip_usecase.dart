import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

/// Parameters for [CreateTripUseCase].
class CreateTripParams extends Equatable {
  final String driverId;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final int totalSeats;
  final double pricePerSeat;
  final double? originLatitude;
  final double? originLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final double? routeDistanceMeters;
  final double? routeDurationSeconds;

  const CreateTripParams({
    required this.driverId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.totalSeats,
    required this.pricePerSeat,
    this.originLatitude,
    this.originLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
  });

  @override
  List<Object?> get props => [
    driverId,
    origin,
    destination,
    departureTime,
    totalSeats,
    pricePerSeat,
    originLatitude,
    originLongitude,
    destinationLatitude,
    destinationLongitude,
    routeDistanceMeters,
    routeDurationSeconds,
  ];
}

/// Use case for creating a new trip.
class CreateTripUseCase implements UseCase<Trip, CreateTripParams> {
  final TripRepository repository;

  const CreateTripUseCase(this.repository);

  @override
  Future<Trip> call(CreateTripParams params) {
    return repository.createTrip(
      params.driverId,
      params.origin,
      params.destination,
      params.departureTime,
      params.totalSeats,
      params.pricePerSeat,
      originLatitude: params.originLatitude,
      originLongitude: params.originLongitude,
      destinationLatitude: params.destinationLatitude,
      destinationLongitude: params.destinationLongitude,
      routeDistanceMeters: params.routeDistanceMeters,
      routeDurationSeconds: params.routeDurationSeconds,
    );
  }
}
