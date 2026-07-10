import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/trip.dart';
import '../repositories/trip_repository.dart';

/// Parameters for [GetMyTripsUseCase].
class GetMyTripsParams extends Equatable {
  final String driverId;

  const GetMyTripsParams({required this.driverId});

  @override
  List<Object?> get props => [driverId];
}

/// Use case for fetching trips created by a specific driver.
class GetMyTripsUseCase implements UseCase<List<Trip>, GetMyTripsParams> {
  final TripRepository repository;

  const GetMyTripsUseCase(this.repository);

  @override
  Future<List<Trip>> call(GetMyTripsParams params) {
    return repository.getMyTrips(params.driverId);
  }
}
