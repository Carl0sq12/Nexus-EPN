import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../../../map/domain/entities/user_location.dart';
import '../models/trip_location_model.dart';

/// Stores and watches the driver's latest location for an in-progress trip.
class TripLocationRemoteDatasource {
  final Databases databases;
  final Realtime realtime;

  const TripLocationRemoteDatasource({
    required this.databases,
    required this.realtime,
  });

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionTripLocations;

  Future<TripLocationModel?> getLocation(String tripId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: tripId,
      );
      return TripLocationModel.fromJson(normalizeDocument(doc));
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        try {
          final response = await databases.listDocuments(
            databaseId: _db,
            collectionId: _col,
            queries: [Query.equal('trip_id', tripId), Query.limit(1)],
          );
          if (response.documents.isEmpty) return null;
          return TripLocationModel.fromJson(
            normalizeDocument(response.documents.first),
          );
        } on AppwriteException catch (fallbackError) {
          if (fallbackError.code == 404) return null;
          throw ServerException(fallbackError.toString());
        }
      }
      throw ServerException(e.toString());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<TripLocationModel>> getRecentLocations({
    required DateTime since,
    int limit = 100,
  }) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.greaterThan('updated_at', since.toUtc().toIso8601String()),
          Query.orderDesc('updated_at'),
          Query.limit(limit),
        ],
      );
      return response.documents
          .map((doc) => TripLocationModel.fromJson(normalizeDocument(doc)))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> upsertLocation({
    required String tripId,
    required String driverId,
    required UserLocation location,
  }) async {
    final heading = location.heading.isFinite ? location.heading : 0.0;
    final speed = location.speed;
    final data = <String, dynamic>{
      'trip_id': tripId,
      'driver_id': driverId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'heading': heading,
      if (speed != null && speed.isFinite) 'speed': speed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await databases.updateDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: tripId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) {
        throw ServerException(e.toString());
      }
      try {
        await databases.createDocument(
          databaseId: _db,
          collectionId: _col,
          documentId: tripId,
          data: data,
          permissions: [
            Permission.read(Role.any()),
            Permission.update(Role.user(driverId)),
            Permission.delete(Role.user(driverId)),
          ],
        );
      } on AppwriteException catch (createError) {
        if (createError.code == 409) {
          await databases.updateDocument(
            databaseId: _db,
            collectionId: _col,
            documentId: tripId,
            data: data,
          );
          return;
        }
        throw ServerException(createError.toString());
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> deleteLocation(String tripId) async {
    try {
      await databases.deleteDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: tripId,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) return;
      throw ServerException(e.toString());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Realtime stream with polling fallback so the passenger map keeps moving
  /// even if the websocket is interrupted by the device/network.
  Stream<TripLocationModel?> watchLocation(String tripId) {
    final controller = StreamController<TripLocationModel?>();
    Timer? pollTimer;
    RealtimeSubscription? subscription;
    TripLocationModel? lastGood;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        final location = await getLocation(tripId);
        if (location != null) lastGood = location;
        if (!controller.isClosed) controller.add(location);
      } catch (e, st) {
        if (lastGood != null) {
          if (!controller.isClosed) controller.add(lastGood);
          return;
        }
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    void startPolling() {
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => emit());
    }

    controller.onListen = () {
      emit();
      try {
        final channel = 'databases.$_db.collections.$_col.documents.$tripId';
        subscription = realtime.subscribe([channel]);
        subscription!.stream.listen(
          (_) => emit(),
          onError: (_) => startPolling(),
        );
        startPolling();
      } catch (_) {
        startPolling();
      }
    };

    controller.onCancel = () async {
      pollTimer?.cancel();
      await subscription?.close();
    };

    return controller.stream;
  }

  Stream<List<TripLocationModel>> watchRecentLocations({
    Duration freshness = const Duration(minutes: 3),
  }) {
    final controller = StreamController<List<TripLocationModel>>();
    Timer? pollTimer;
    RealtimeSubscription? subscription;
    List<TripLocationModel>? lastGood;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        final locations = await getRecentLocations(
          since: DateTime.now().subtract(freshness),
        );
        lastGood = locations;
        if (!controller.isClosed) controller.add(locations);
      } catch (e, st) {
        if (lastGood != null) {
          if (!controller.isClosed) controller.add(lastGood!);
          return;
        }
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    void startPolling() {
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => emit());
    }

    controller.onListen = () {
      emit();
      try {
        final channel = 'databases.$_db.collections.$_col.documents';
        subscription = realtime.subscribe([channel]);
        subscription!.stream.listen(
          (_) => emit(),
          onError: (_) => startPolling(),
        );
        startPolling();
      } catch (_) {
        startPolling();
      }
    };

    controller.onCancel = () async {
      pollTimer?.cancel();
      await subscription?.close();
    };

    return controller.stream;
  }
}
