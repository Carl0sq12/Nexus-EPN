import '../../../../core/usecase/usecase.dart';
import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

/// Use case for obtaining the device's current location.
class GetCurrentLocationUseCase implements UseCase<UserLocation, NoParams> {
  final LocationRepository repository;

  const GetCurrentLocationUseCase(this.repository);

  @override
  Future<UserLocation> call(NoParams params) {
    return repository.getCurrentLocation();
  }
}
