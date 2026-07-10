import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/trip_request.dart';
import '../repositories/request_repository.dart';

/// Parameters for [SendRequestUseCase].
class SendRequestParams extends Equatable {
  final String tripId;
  final String passengerId;
  final int passengerCount;
  final String? pickupNote;
  final String? dropoffNote;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final List<TripRequestStop> stops;

  const SendRequestParams({
    required this.tripId,
    required this.passengerId,
    this.passengerCount = 1,
    this.pickupNote,
    this.dropoffNote,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.stops = const [],
  });

  @override
  List<Object?> get props => [
    tripId,
    passengerId,
    passengerCount,
    pickupNote,
    dropoffNote,
    pickupLatitude,
    pickupLongitude,
    dropoffLatitude,
    dropoffLongitude,
    stops,
  ];
}

/// Use case for sending a trip join request.
class SendRequestUseCase implements UseCase<TripRequest, SendRequestParams> {
  final RequestRepository repository;

  const SendRequestUseCase(this.repository);

  @override
  Future<TripRequest> call(SendRequestParams params) {
    return repository.sendRequest(
      params.tripId,
      params.passengerId,
      passengerCount: params.passengerCount,
      pickupNote: params.pickupNote,
      dropoffNote: params.dropoffNote,
      pickupLatitude: params.pickupLatitude,
      pickupLongitude: params.pickupLongitude,
      dropoffLatitude: params.dropoffLatitude,
      dropoffLongitude: params.dropoffLongitude,
      stops: params.stops,
    );
  }
}
