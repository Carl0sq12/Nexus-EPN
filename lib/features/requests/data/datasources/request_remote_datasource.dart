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

  Future<List<TripRequestModel>> getRequestsByTripId(String tripId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [Query.equal('trip_id', tripId), Query.limit(100)],
      );
      final requests = response.documents
          .map((d) => TripRequestModel.fromJson(normalizeDocument(d)))
          .toList();
      requests.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return requests;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<TripRequestModel>> getRequestsByTripIds(
    Iterable<String> tripIds,
  ) async {
    final ids = tripIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];

    try {
      const chunkSize = 25;
      const pageSize = 100;
      final requests = <TripRequestModel>[];

      for (var start = 0; start < ids.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, ids.length);
        final chunk = ids.sublist(start, end);
        var offset = 0;

        while (true) {
          final response = await databases.listDocuments(
            databaseId: _db,
            collectionId: _col,
            queries: [
              Query.equal('trip_id', chunk),
              Query.limit(pageSize),
              Query.offset(offset),
            ],
          );

          requests.addAll(
            response.documents.map(
              (d) => TripRequestModel.fromJson(normalizeDocument(d)),
            ),
          );

          if (response.documents.length < pageSize) break;
          offset += pageSize;
        }
      }

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
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
        queries: [Query.equal('passenger_id', passengerId), Query.limit(100)],
      );

      // Keep pending / proposed / accepted / rejected for passenger history.
      final requests = response.documents
          .map((d) => TripRequestModel.fromJson(normalizeDocument(d)))
          .where((request) => request.status != 'cancelled')
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
