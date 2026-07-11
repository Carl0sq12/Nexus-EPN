import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../domain/entities/trip.dart';
import '../../domain/usecases/get_available_trips_usecase.dart';
import '../../domain/usecases/get_my_trips_usecase.dart';
import '../../domain/usecases/create_trip_usecase.dart';
import '../../domain/usecases/update_trip_usecase.dart';
import '../../domain/usecases/delete_trip_usecase.dart';
import '../../data/datasources/trip_remote_datasource.dart';
import '../../data/repositories/trip_repository_impl.dart';
import '../../../../core/usecase/usecase.dart';

/// Provider for the trip remote datasource.
final tripDatasourceProvider = Provider<TripRemoteDatasource>((ref) {
  return TripRemoteDatasource(ref.watch(databasesProvider));
});

/// Provider for the trip repository.
final tripRepositoryProvider = Provider<TripRepositoryImpl>((ref) {
  return TripRepositoryImpl(ref.watch(tripDatasourceProvider));
});

/// Fetches all available trips.
final availableTripsProvider = FutureProvider<List<Trip>>((ref) {
  final useCase = GetAvailableTripsUseCase(ref.watch(tripRepositoryProvider));
  return useCase(const NoParams());
});

/// Fetches trips created by a specific driver.
final myTripsProvider = FutureProvider.family<List<Trip>, String>((
  ref,
  driverId,
) {
  final useCase = GetMyTripsUseCase(ref.watch(tripRepositoryProvider));
  return useCase(GetMyTripsParams(driverId: driverId));
});

/// Fetches a trip by id, including completed/full trips that are not available.
final tripByIdProvider = FutureProvider.family<Trip, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getTripById(tripId);
});

/// State notifier that manages trip create/update/delete actions.
class TripNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  TripNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> createTrip(
    String driverId,
    String origin,
    String destination,
    DateTime departureTime,
    int totalSeats,
    double pricePerSeat, {
    double? originLatitude,
    double? originLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    double? routeDistanceMeters,
    double? routeDurationSeconds,
    String? routePoints,
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = CreateTripUseCase(ref.read(tripRepositoryProvider));
      await useCase(
        CreateTripParams(
          driverId: driverId,
          origin: origin,
          destination: destination,
          departureTime: departureTime,
          totalSeats: totalSeats,
          pricePerSeat: pricePerSeat,
          originLatitude: originLatitude,
          originLongitude: originLongitude,
          destinationLatitude: destinationLatitude,
          destinationLongitude: destinationLongitude,
          routeDistanceMeters: routeDistanceMeters,
          routeDurationSeconds: routeDurationSeconds,
          routePoints: routePoints,
        ),
      );
      ref.invalidate(availableTripsProvider);
      ref.invalidate(myTripsProvider(driverId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateTrip(
    String tripId,
    String driverId,
    Map<String, dynamic> fields,
  ) async {
    state = const AsyncValue.loading();
    try {
      final useCase = UpdateTripUseCase(ref.read(tripRepositoryProvider));
      await useCase(UpdateTripParams(tripId: tripId, fields: fields));
      ref.invalidate(availableTripsProvider);
      ref.invalidate(myTripsProvider(driverId));
      ref.invalidate(tripByIdProvider(tripId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTrip(String tripId, String driverId) async {
    state = const AsyncValue.loading();
    try {
      final useCase = DeleteTripUseCase(ref.read(tripRepositoryProvider));
      await useCase(DeleteTripParams(tripId: tripId));
      ref.invalidate(availableTripsProvider);
      ref.invalidate(myTripsProvider(driverId));
      ref.invalidate(tripByIdProvider(tripId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for [TripNotifier] that exposes trip create/update/delete actions.
final tripNotifierProvider =
    StateNotifierProvider<TripNotifier, AsyncValue<void>>((ref) {
      return TripNotifier(ref);
    });
