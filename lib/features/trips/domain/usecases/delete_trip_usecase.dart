import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/trip_repository.dart';

/// Parameters for [DeleteTripUseCase].
class DeleteTripParams extends Equatable {
  final String tripId;

  const DeleteTripParams({required this.tripId});

  @override
  List<Object?> get props => [tripId];
}

/// Use case for soft-deleting (cancelling) a trip.
class DeleteTripUseCase implements UseCase<void, DeleteTripParams> {
  final TripRepository repository;

  const DeleteTripUseCase(this.repository);

  @override
  Future<void> call(DeleteTripParams params) {
    return repository.deleteTrip(params.tripId);
  }
}
