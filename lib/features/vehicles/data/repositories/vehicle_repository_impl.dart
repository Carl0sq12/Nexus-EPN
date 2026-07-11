import 'dart:io';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../../../core/errors/failure.dart';
import '../datasources/vehicle_remote_datasource.dart';

/// Implementation of [VehicleRepository] using [VehicleRemoteDatasource].
class VehicleRepositoryImpl implements VehicleRepository {
  final VehicleRemoteDatasource datasource;

  const VehicleRepositoryImpl(this.datasource);

  @override
  Future<Vehicle?> getMyVehicle(String driverId) async {
    try {
      return await datasource.getMyVehicle(driverId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<Vehicle> createVehicle(
    String driverId,
    String brand,
    String model,
    String color,
    String plate,
    String? licensePhotoUrl,
  ) async {
    try {
      return await datasource.createVehicle(
        driverId,
        brand,
        model,
        color,
        plate,
        licensePhotoUrl,
      );
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<Vehicle> updateVehicle(
    String vehicleId,
    Map<String, dynamic> fields,
  ) async {
    try {
      return await datasource.updateVehicle(vehicleId, fields);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> uploadVehiclePhoto(
    String vehicleId,
    File file, {
    String? previousUrl,
    String? ownerUserId,
  }) async {
    try {
      return await datasource.uploadVehiclePhoto(
        vehicleId,
        file,
        previousUrl: previousUrl,
        ownerUserId: ownerUserId,
      );
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> uploadLicensePhoto(
    String vehicleId,
    File file, {
    String? previousUrl,
    String? ownerUserId,
  }) async {
    try {
      return await datasource.uploadLicensePhoto(
        vehicleId,
        file,
        previousUrl: previousUrl,
        ownerUserId: ownerUserId,
      );
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await datasource.deleteVehicle(vehicleId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
