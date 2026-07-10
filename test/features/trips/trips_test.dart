import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_campus/core/errors/failure.dart';
import 'package:nexus_campus/features/trips/data/datasources/trip_remote_datasource.dart';
import 'package:nexus_campus/features/trips/data/models/trip_model.dart';
import 'package:nexus_campus/features/trips/data/repositories/trip_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('TripRepositoryImpl', () {
    final trip = TripModel(
      id: 'trip-1',
      driverId: 'driver-1',
      origin: 'EPN',
      destination: 'Centro',
      departureTime: DateTime(2026, 7, 8, 8),
      totalSeats: 4,
      availableSeats: 2,
      pricePerSeat: 1.5,
      status: 'active',
    );

    test('getAvailableTrips delegates to the datasource', () async {
      final datasource = _FakeTripRemoteDatasource(availableTrips: [trip]);
      final repository = TripRepositoryImpl(datasource);

      final result = await repository.getAvailableTrips();

      expect(result, [trip]);
      expect(datasource.getAvailableTripsCalled, isTrue);
    });

    test('updateTrip delegates fields and returns the updated trip', () async {
      final updatedTrip = TripModel(
        id: trip.id,
        driverId: trip.driverId,
        origin: trip.origin,
        destination: trip.destination,
        departureTime: trip.departureTime,
        totalSeats: trip.totalSeats,
        availableSeats: trip.availableSeats,
        pricePerSeat: trip.pricePerSeat,
        status: 'completed',
      );
      final datasource = _FakeTripRemoteDatasource(updatedTrip: updatedTrip);
      final repository = TripRepositoryImpl(datasource);

      final result = await repository.updateTrip('trip-1', {
        'status': 'completed',
      });

      expect(result, updatedTrip);
      expect(datasource.updatedTripId, 'trip-1');
      expect(datasource.updatedFields, {'status': 'completed'});
    });

    test('wraps datasource errors in ServerFailure', () async {
      final datasource = _FakeTripRemoteDatasource(error: Exception('boom'));
      final repository = TripRepositoryImpl(datasource);

      expect(repository.getAvailableTrips(), throwsA(isA<ServerFailure>()));
    });
  });
}

class _FakeTripRemoteDatasource implements TripRemoteDatasource {
  final List<TripModel> availableTrips;
  final TripModel? updatedTrip;
  final Object? error;
  bool getAvailableTripsCalled = false;
  String? updatedTripId;
  Map<String, dynamic>? updatedFields;

  _FakeTripRemoteDatasource({
    this.availableTrips = const [],
    this.updatedTrip,
    this.error,
  });

  @override
  SupabaseClient get client => throw UnimplementedError();

  void _throwIfNeeded() {
    if (error != null) throw error!;
  }

  @override
  Future<List<TripModel>> getAvailableTrips() async {
    getAvailableTripsCalled = true;
    _throwIfNeeded();
    return availableTrips;
  }

  @override
  Future<List<TripModel>> getMyTrips(String driverId) async {
    _throwIfNeeded();
    return const [];
  }

  @override
  Future<TripModel> getTripById(String tripId) async {
    _throwIfNeeded();
    return availableTrips.first;
  }

  @override
  Future<TripModel> createTrip(
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
  }) async {
    _throwIfNeeded();
    return availableTrips.first;
  }

  @override
  Future<TripModel> updateTrip(
    String tripId,
    Map<String, dynamic> fields,
  ) async {
    updatedTripId = tripId;
    updatedFields = fields;
    _throwIfNeeded();
    return updatedTrip ?? availableTrips.first;
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    _throwIfNeeded();
  }
}
