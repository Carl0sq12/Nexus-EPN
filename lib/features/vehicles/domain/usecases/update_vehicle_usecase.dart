import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/vehicle.dart';
import '../repositories/vehicle_repository.dart';

/// Parameters for [UpdateVehicleUseCase].
class UpdateVehicleParams extends Equatable {
  final String vehicleId;
  final Map<String, dynamic> fields;

  const UpdateVehicleParams({required this.vehicleId, required this.fields});

  @override
  List<Object?> get props => [vehicleId, fields];
}

/// Use case for updating vehicle fields.
class UpdateVehicleUseCase implements UseCase<Vehicle, UpdateVehicleParams> {
  final VehicleRepository repository;

  const UpdateVehicleUseCase(this.repository);

  @override
  Future<Vehicle> call(UpdateVehicleParams params) {
    return repository.updateVehicle(params.vehicleId, params.fields);
  }
}
