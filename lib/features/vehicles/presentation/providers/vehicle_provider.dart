import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/providers/session_data_provider.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/usecases/get_my_vehicle_usecase.dart';
import '../../domain/usecases/create_vehicle_usecase.dart';
import '../../domain/usecases/update_vehicle_usecase.dart';
import '../../data/datasources/vehicle_remote_datasource.dart';
import '../../data/repositories/vehicle_repository_impl.dart';

/// Provider for the vehicle remote datasource.
final vehicleDatasourceProvider = Provider<VehicleRemoteDatasource>((ref) {
  return VehicleRemoteDatasource(ref.watch(supabaseClientProvider));
});

/// Provider for the vehicle repository.
final vehicleRepositoryProvider = Provider<VehicleRepositoryImpl>((ref) {
  return VehicleRepositoryImpl(ref.watch(vehicleDatasourceProvider));
});

/// Fetches the vehicle for a given driver ID.
final myVehicleProvider = FutureProvider.family<Vehicle?, String>((
  ref,
  driverId,
) {
  final useCase = GetMyVehicleUseCase(ref.watch(vehicleRepositoryProvider));
  return useCase(GetMyVehicleParams(driverId: driverId));
});

/// State notifier that manages vehicle create/update actions.
class VehicleNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  VehicleNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> createVehicle(
    String driverId,
    String brand,
    String model,
    String color,
    String plate,
  ) async {
    state = const AsyncValue.loading();
    try {
      final useCase = CreateVehicleUseCase(ref.read(vehicleRepositoryProvider));
      await useCase(
        CreateVehicleParams(
          driverId: driverId,
          brand: brand,
          model: model,
          color: color,
          plate: plate,
        ),
      );
      ref.invalidate(myVehicleProvider(driverId));
      ref.read(sessionDataVersionProvider.notifier).state++;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createVehicleWithPhoto(
    String driverId,
    String brand,
    String model,
    String color,
    String plate,
    File photo,
  ) async {
    state = const AsyncValue.loading();
    try {
      // Business rule: onboarding drivers must register a vehicle with photo
      // before accessing Home or driver-only features.
      final createUseCase = CreateVehicleUseCase(
        ref.read(vehicleRepositoryProvider),
      );
      final vehicle = await createUseCase(
        CreateVehicleParams(
          driverId: driverId,
          brand: brand,
          model: model,
          color: color,
          plate: plate,
        ),
      );
      final repository = ref.read(vehicleRepositoryProvider);
      final photoUrl = await repository.uploadVehiclePhoto(vehicle.id, photo);
      final updateUseCase = UpdateVehicleUseCase(repository);
      await updateUseCase(
        UpdateVehicleParams(
          vehicleId: vehicle.id,
          fields: {'photo_url': photoUrl},
        ),
      );
      ref.invalidate(myVehicleProvider(driverId));
      ref.read(sessionDataVersionProvider.notifier).state++;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateVehicle(
    String vehicleId,
    String driverId,
    Map<String, dynamic> fields,
  ) async {
    state = const AsyncValue.loading();
    try {
      final useCase = UpdateVehicleUseCase(ref.read(vehicleRepositoryProvider));
      await useCase(UpdateVehicleParams(vehicleId: vehicleId, fields: fields));
      ref.invalidate(myVehicleProvider(driverId));
      ref.read(sessionDataVersionProvider.notifier).state++;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for [VehicleNotifier] that exposes vehicle create/update actions.
final vehicleNotifierProvider =
    StateNotifierProvider<VehicleNotifier, AsyncValue<void>>((ref) {
      return VehicleNotifier(ref);
    });
