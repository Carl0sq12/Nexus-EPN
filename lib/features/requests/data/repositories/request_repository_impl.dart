import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/trip_request.dart';
import '../../domain/repositories/request_repository.dart';
import '../datasources/request_remote_datasource.dart';
import '../models/trip_request_model.dart';

/// Implementation of [RequestRepository] using Supabase.
class RequestRepositoryImpl implements RequestRepository {
  final RequestRemoteDatasource remoteDatasource;
  final SupabaseClient supabaseClient;

  const RequestRepositoryImpl(this.remoteDatasource, this.supabaseClient);

  @override
  Future<List<TripRequest>> getRequestsForTrip(String tripId) async {
    try {
      return await remoteDatasource.getRequestsByTripId(tripId);
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
      final request = await supabaseClient
          .from('trip_requests')
          .select('id, status')
          .eq('id', requestId)
          .eq('trip_id', tripId)
          .single();
      if (request['status'] != 'pending') {
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
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> acceptProposedPrice(
    String requestId,
    String tripId,
  ) async {
    try {
      final response = await supabaseClient.rpc(
        'accept_proposed_trip_price',
        params: {'p_request_id': requestId, 'p_trip_id': tripId},
      );
      return TripRequestModel.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TripRequest> acceptRequest(String requestId, String tripId) async {
    try {
      final requestResponse = await supabaseClient
          .from('trip_requests')
          .select('passenger_count')
          .eq('id', requestId)
          .eq('trip_id', tripId)
          .single();
      final requestedSeats = requestResponse['passenger_count'] as int? ?? 1;
      final tripResponse = await supabaseClient
          .from('trips')
          .select('available_seats')
          .eq('id', tripId)
          .single();
      final currentSeats = tripResponse['available_seats'] as int;
      if (currentSeats < requestedSeats) {
        throw const ServerException('No hay suficientes asientos disponibles');
      }
      final nextSeats = currentSeats - requestedSeats;
      await supabaseClient
          .from('trips')
          .update({
            'available_seats': nextSeats,
            if (nextSeats == 0) 'status': 'full',
          })
          .eq('id', tripId);
      final request = await remoteDatasource.updateRequestStatus(
        requestId,
        'accepted',
      );
      return request;
    } catch (e) {
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
}
