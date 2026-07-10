import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/vehicle.dart';
import '../repositories/vehicle_repository.dart';

/// Parameters for [CreateVehicleUseCase].
class CreateVehicleParams extends Equatable {
  final String driverId;
  final String brand;
  final String model;
  final String color;
  final String plate;

  const CreateVehicleParams({
    required this.driverId,
    required this.brand,
    required this.model,
    required this.color,
    required this.plate,
  });

  @override
  List<Object?> get props => [driverId, brand, model, color, plate];
}

/// Use case for creating a new vehicle.
class CreateVehicleUseCase implements UseCase<Vehicle, CreateVehicleParams> {
  final VehicleRepository repository;

  const CreateVehicleUseCase(this.repository);

  @override
  Future<Vehicle> call(CreateVehicleParams params) {
    return repository.createVehicle(
      params.driverId,
      params.brand,
      params.model,
      params.color,
      params.plate,
    );
  }
}
