import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

/// Parameters for [UpdateTripUseCase].
class UpdateTripParams extends Equatable {
  final String tripId;
  final Map<String, dynamic> fields;

  const UpdateTripParams({required this.tripId, required this.fields});

  @override
  List<Object?> get props => [tripId, fields];
}

/// Use case for updating trip fields.
class UpdateTripUseCase implements UseCase<Trip, UpdateTripParams> {
  final TripRepository repository;

  const UpdateTripUseCase(this.repository);

  @override
  Future<Trip> call(UpdateTripParams params) {
    return repository.updateTrip(params.tripId, params.fields);
  }
}
