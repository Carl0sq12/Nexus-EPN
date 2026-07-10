import '../../../../core/usecase/usecase.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

/// Use case for fetching all available trips.
class GetAvailableTripsUseCase implements UseCase<List<Trip>, NoParams> {
  final TripRepository repository;

  const GetAvailableTripsUseCase(this.repository);

  @override
  Future<List<Trip>> call(NoParams params) {
    return repository.getAvailableTrips();
  }
}
