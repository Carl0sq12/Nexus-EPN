import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/vehicle_model.dart';

/// Remote datasource for vehicle operations using Supabase.
class VehicleRemoteDatasource {
  final SupabaseClient client;

  const VehicleRemoteDatasource(this.client);

  Future<VehicleModel?> getMyVehicle(String driverId) async {
    try {
      final response = await client
          .from('vehicles')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();
      if (response == null) return null;
      return VehicleModel.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<VehicleModel> createVehicle(
    String driverId,
    String brand,
    String model,
    String color,
    String plate,
  ) async {
    try {
      final response = await client
          .from('vehicles')
          .insert({
            'driver_id': driverId,
            'brand': brand,
            'model': model,
            'color': color,
            'plate': plate,
          })
          .select()
          .single();
      return VehicleModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<VehicleModel> updateVehicle(
    String vehicleId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final response = await client
          .from('vehicles')
          .update(fields)
          .eq('id', vehicleId)
          .select()
          .single();
      return VehicleModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<String> uploadVehiclePhoto(String vehicleId, File file) async {
    try {
      await client.storage
          .from('vehicles')
          .upload(
            '$vehicleId.jpg',
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return client.storage.from('vehicles').getPublicUrl('$vehicleId.jpg');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
