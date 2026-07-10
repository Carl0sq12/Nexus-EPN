import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/vehicle.dart';
import '../repositories/vehicle_repository.dart';

/// Parameters for [GetMyVehicleUseCase].
class GetMyVehicleParams extends Equatable {
  final String driverId;

  const GetMyVehicleParams({required this.driverId});

  @override
  List<Object?> get props => [driverId];
}

/// Use case for fetching the vehicle of a given driver.
class GetMyVehicleUseCase implements UseCase<Vehicle?, GetMyVehicleParams> {
  final VehicleRepository repository;

  const GetMyVehicleUseCase(this.repository);

  @override
  Future<Vehicle?> call(GetMyVehicleParams params) {
    return repository.getMyVehicle(params.driverId);
  }
}
