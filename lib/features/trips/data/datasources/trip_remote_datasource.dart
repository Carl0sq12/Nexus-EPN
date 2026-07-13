import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/constants/app_limits.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../models/trip_model.dart';

/// Remote datasource for trip operations using Appwrite Databases.
class TripRemoteDatasource {
  final Databases databases;

  const TripRemoteDatasource(this.databases);

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionTrips;

  Future<List<TripModel>> getAvailableTrips() async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('status', 'active'),
          Query.greaterThan('available_seats', 0),
          Query.orderAsc('departure_time'),
        ],
      );
      return response.documents
          .map((d) => TripModel.fromJson(normalizeDocument(d)))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<TripModel>> getMyTrips(String driverId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('driver_id', driverId),
          Query.orderAsc('departure_time'),
        ],
      );
      return response.documents
          .map((d) => TripModel.fromJson(normalizeDocument(d)))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<TripModel> getTripById(String tripId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: tripId,
      );
      return TripModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

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
    String? routePoints,
  }) async {
    try {
      if (totalSeats < 1 || totalSeats > AppLimits.maxTripSeats) {
        throw const ServerException(
          'El viaje debe tener entre 1 y 4 asientos disponibles',
        );
      }
      final data = <String, dynamic>{
        'driver_id': driverId,
        'origin': origin,
        'destination': destination,
        'departure_time': departureTime.toUtc().toIso8601String(),
        'total_seats': totalSeats,
        'available_seats': totalSeats,
        'price_per_seat': pricePerSeat,
        'status': 'active',
        if (originLatitude != null) 'origin_latitude': originLatitude,
        if (originLongitude != null) 'origin_longitude': originLongitude,
        if (destinationLatitude != null)
          'destination_latitude': destinationLatitude,
        if (destinationLongitude != null)
          'destination_longitude': destinationLongitude,
        if (routeDistanceMeters != null)
          'route_distance_meters': routeDistanceMeters,
        if (routeDurationSeconds != null)
          'route_duration_seconds': routeDurationSeconds,
        if (routePoints != null) 'route_points': routePoints,
      };

      final doc = await databases.createDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: ID.unique(),
        data: data,
        permissions: tripDocumentPermissions(driverId),
      );
      return TripModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<TripModel> updateTrip(
    String tripId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final totalSeats = fields['total_seats'];
      if (totalSeats is num &&
          (totalSeats < 1 || totalSeats > AppLimits.maxTripSeats)) {
        throw const ServerException(
          'El viaje debe tener entre 1 y 4 asientos disponibles',
        );
      }
      final availableSeats = fields['available_seats'];
      if (availableSeats is num &&
          (availableSeats < 0 || availableSeats > AppLimits.maxTripSeats)) {
        throw const ServerException(
          'El viaje debe tener máximo 4 asientos disponibles',
        );
      }
      final doc = await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: tripId,
        data: fields,
      );
      return TripModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: tripId,
        data: {'status': 'cancelled'},
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
