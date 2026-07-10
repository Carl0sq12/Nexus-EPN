import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../../../core/errors/failure.dart';
import '../datasources/trip_remote_datasource.dart';

/// Implementation of [TripRepository] using [TripRemoteDatasource].
class TripRepositoryImpl implements TripRepository {
  final TripRemoteDatasource datasource;

  const TripRepositoryImpl(this.datasource);

  @override
  Future<List<Trip>> getAvailableTrips() async {
    try {
      return await datasource.getAvailableTrips();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<Trip>> getMyTrips(String driverId) async {
    try {
      return await datasource.getMyTrips(driverId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<Trip> getTripById(String tripId) async {
    try {
      return await datasource.getTripById(tripId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<Trip> createTrip(
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
    try {
      return await datasource.createTrip(
        driverId,
        origin,
        destination,
        departureTime,
        totalSeats,
        pricePerSeat,
        originLatitude: originLatitude,
        originLongitude: originLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        routeDistanceMeters: routeDistanceMeters,
        routeDurationSeconds: routeDurationSeconds,
      );
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<Trip> updateTrip(String tripId, Map<String, dynamic> fields) async {
    try {
      return await datasource.updateTrip(tripId, fields);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    try {
      await datasource.deleteTrip(tripId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
