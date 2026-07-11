import 'dart:convert';

import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../../domain/entities/trip_request.dart';
import '../models/trip_request_model.dart';

/// Remote datasource for trip request operations using Appwrite Databases.
class RequestRemoteDatasource {
  final Databases databases;

  const RequestRemoteDatasource(this.databases);

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionTripRequests;
  String get _tripsCol => AppwriteConfig.collectionTrips;

  Future<List<TripRequestModel>> getRequestsByTripId(String tripId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('trip_id', tripId),
          Query.orderAsc(r'$createdAt'),
        ],
      );
      return response.documents
          .map((d) => TripRequestModel.fromJson(normalizeDocument(d)))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<TripRequestModel> getRequestById(String requestId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: requestId,
      );
      return TripRequestModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<TripRequestModel> sendRequest(
    String tripId,
    String passengerId, {
    int passengerCount = 1,
    String? pickupNote,
    String? dropoffNote,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    List<TripRequestStop> stops = const [],
  }) async {
    try {
      final existing = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('trip_id', tripId),
          Query.equal('passenger_id', passengerId),
          Query.equal('status', ['pending', 'accepted', 'price_proposed']),
          Query.limit(1),
        ],
      );

      if (existing.documents.isNotEmpty) {
        throw const ServerException(
          'Ya tienes una solicitud activa para este viaje',
        );
      }

      final stopsJson = jsonEncode(
        stops
            .map(
              (stop) => {
                'label': stop.label,
                'latitude': stop.latitude,
                'longitude': stop.longitude,
              },
            )
            .toList(),
      );

      final data = <String, dynamic>{
        'trip_id': tripId,
        'passenger_id': passengerId,
        'status': 'pending',
        'passenger_count': passengerCount,
        'request_stops': stopsJson,
        if (pickupNote != null) 'pickup_note': pickupNote,
        if (dropoffNote != null) 'dropoff_note': dropoffNote,
        if (pickupLatitude != null) 'pickup_latitude': pickupLatitude,
        if (pickupLongitude != null) 'pickup_longitude': pickupLongitude,
        if (dropoffLatitude != null) 'dropoff_latitude': dropoffLatitude,
        if (dropoffLongitude != null) 'dropoff_longitude': dropoffLongitude,
      };

      final doc = await databases.createDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: ID.unique(),
        data: data,
        permissions: ownerPermissions(passengerId),
      );
      return TripRequestModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  Future<TripRequestModel> updateRequestStatus(
    String requestId,
    String status,
  ) async {
    try {
      final doc = await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: requestId,
        data: {'status': status},
      );
      return TripRequestModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> deleteRequest(String requestId) async {
    try {
      await databases.deleteDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: requestId,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<TripRequestModel> proposePrice(
    String requestId, {
    required double proposedPrice,
    String? priceNote,
  }) async {
    try {
      final doc = await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: requestId,
        data: {
          'status': 'price_proposed',
          'proposed_price': proposedPrice,
          if (priceNote != null) 'price_note': priceNote,
        },
      );
      return TripRequestModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<TripRequestModel>> getMyRequests(String passengerId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('passenger_id', passengerId),
          Query.orderDesc(r'$createdAt'),
        ],
      );

      // Keep pending / proposed / accepted / rejected for passenger history.
      return response.documents
          .map((d) => TripRequestModel.fromJson(normalizeDocument(d)))
          .where((request) => request.status != 'cancelled')
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
