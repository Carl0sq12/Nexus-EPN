import '../../../../core/errors/exceptions.dart';
import '../../../trips/data/datasources/trip_remote_datasource.dart';
import '../../domain/entities/trip_request.dart';
import '../../domain/repositories/request_repository.dart';
import '../datasources/request_remote_datasource.dart';

/// Implementation of [RequestRepository] using Appwrite datasources.
class RequestRepositoryImpl implements RequestRepository {
  final RequestRemoteDatasource remoteDatasource;
  final TripRemoteDatasource tripDatasource;

  const RequestRepositoryImpl(this.remoteDatasource, this.tripDatasource);

  @override
  Future<List<TripRequest>> getRequestsForTrip(String tripId) async {
    try {
      return await remoteDatasource.getRequestsByTripId(tripId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TripRequest>> getRequestsForTrips(
    Iterable<String> tripIds,
  ) async {
    try {
      return await remoteDatasource.getRequestsByTripIds(tripIds);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TripRequest>> getMyRequests(String passengerId) async {
    try {
      return await remoteDatasource.getMyRequests(passengerId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> getRequestById(String requestId) async {
    try {
      return await remoteDatasource.getRequestById(requestId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> sendRequest(
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
      return await remoteDatasource.sendRequest(
        tripId,
        passengerId,
        passengerCount: passengerCount,
        pickupNote: pickupNote,
        dropoffNote: dropoffNote,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        dropoffLatitude: dropoffLatitude,
        dropoffLongitude: dropoffLongitude,
        stops: stops,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> proposePrice(
    String requestId,
    String tripId, {
    required double proposedPrice,
    String? priceNote,
  }) async {
    try {
      final request = await remoteDatasource.getRequestById(requestId);
      if (request.tripId != tripId) {
        throw const ServerException('La solicitud no pertenece a este viaje');
      }
      if (request.status != 'pending') {
        throw const ServerException(
          'Solo puedes proponer precio a solicitudes pendientes',
        );
      }
      return await remoteDatasource.proposePrice(
        requestId,
        proposedPrice: proposedPrice,
        priceNote: priceNote,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> acceptProposedPrice(
    String requestId,
    String tripId,
  ) async {
    try {
      final request = await remoteDatasource.getRequestById(requestId);
      if (request.tripId != tripId) {
        throw const ServerException('La solicitud no pertenece a este viaje');
      }
      if (request.status != 'price_proposed') {
        throw const ServerException('Solo puedes aceptar un precio propuesto');
      }

      final trip = await tripDatasource.getTripById(tripId);
      final requestedSeats = request.passengerCount;
      if (trip.availableSeats < requestedSeats) {
        throw const ServerException('No hay suficientes asientos disponibles');
      }

      final nextSeats = trip.availableSeats - requestedSeats;
      await tripDatasource.updateTrip(tripId, {
        'available_seats': nextSeats,
        if (nextSeats == 0) 'status': 'full',
      });

      return await remoteDatasource.updateRequestStatus(requestId, 'accepted');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> acceptRequest(String requestId, String tripId) async {
    try {
      final request = await remoteDatasource.getRequestById(requestId);
      if (request.tripId != tripId) {
        throw const ServerException('La solicitud no pertenece a este viaje');
      }
      final requestedSeats = request.passengerCount;
      final trip = await tripDatasource.getTripById(tripId);
      if (trip.availableSeats < requestedSeats) {
        throw const ServerException('No hay suficientes asientos disponibles');
      }
      final nextSeats = trip.availableSeats - requestedSeats;
      await tripDatasource.updateTrip(tripId, {
        'available_seats': nextSeats,
        if (nextSeats == 0) 'status': 'full',
      });
      return await remoteDatasource.updateRequestStatus(requestId, 'accepted');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> rejectRequest(String requestId) async {
    try {
      return await remoteDatasource.updateRequestStatus(requestId, 'rejected');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> cancelRequest(String requestId) async {
    try {
      final request = await remoteDatasource.getRequestById(requestId);
      const cancellableStatuses = {'pending', 'accepted', 'price_proposed'};
      if (!cancellableStatuses.contains(request.status)) {
        throw const ServerException('Esta solicitud ya no se puede cancelar');
      }

      if (request.status == 'accepted') {
        try {
          final trip = await tripDatasource.getTripById(request.tripId);
          final restoredSeats = (trip.availableSeats + request.passengerCount)
              .clamp(0, trip.totalSeats);
          await tripDatasource.updateTrip(request.tripId, {
            'available_seats': restoredSeats,
            if (trip.status == 'full') 'status': 'active',
          });
        } catch (_) {
          // Seat restore is best-effort; cancel must still succeed.
        }
      }

      // Appwrite enum historically lacked `cancelled`. Prefer status update,
      // fall back to deleting the document so cancel always works.
      try {
        return await remoteDatasource.updateRequestStatus(
          requestId,
          'cancelled',
        );
      } catch (_) {
        await remoteDatasource.deleteRequest(requestId);
        return TripRequest(
          id: request.id,
          tripId: request.tripId,
          passengerId: request.passengerId,
          status: 'cancelled',
          passengerCount: request.passengerCount,
          pickupNote: request.pickupNote,
          dropoffNote: request.dropoffNote,
          pickupLatitude: request.pickupLatitude,
          pickupLongitude: request.pickupLongitude,
          dropoffLatitude: request.dropoffLatitude,
          dropoffLongitude: request.dropoffLongitude,
          stops: request.stops,
          proposedPrice: request.proposedPrice,
          priceNote: request.priceNote,
          createdAt: request.createdAt,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
