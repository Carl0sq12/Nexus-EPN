import 'dart:io';
import '../entities/vehicle.dart';

/// Abstract repository for vehicle-related operations.
abstract class VehicleRepository {
  /// Returns the vehicle owned by [driverId], or null if none registered.
  Future<Vehicle?> getMyVehicle(String driverId);

  /// Creates a new vehicle for the given driver.
  Future<Vehicle> createVehicle(
    String driverId,
    String brand,
    String model,
    String color,
    String plate,
    String? licensePhotoUrl,
  );

  /// Updates specific [fields] for the vehicle identified by [vehicleId].
  Future<Vehicle> updateVehicle(String vehicleId, Map<String, dynamic> fields);

  /// Uploads a vehicle photo [file] and returns the public URL.
  Future<String> uploadVehiclePhoto(
    String vehicleId,
    File file, {
    String? previousUrl,
    String? ownerUserId,
  });

  /// Uploads the vehicle registration/license photo and returns its URL.
  Future<String> uploadLicensePhoto(
    String vehicleId,
    File file, {
    String? previousUrl,
    String? ownerUserId,
  });

  /// Deletes a vehicle and its uploaded photos.
  Future<void> deleteVehicle(String vehicleId);
}
