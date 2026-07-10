import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/trip_request.dart';
import '../models/trip_request_model.dart';

/// Remote datasource for trip request operations using Supabase.
class RequestRemoteDatasource {
  final SupabaseClient client;

  const RequestRemoteDatasource(this.client);

  Future<List<TripRequestModel>> getRequestsByTripId(String tripId) async {
    try {
      final response = await client
          .from('trip_requests')
          .select()
          .eq('trip_id', tripId)
          .order('created_at');
      final list = (response as List)
          .map((e) => TripRequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
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
      final existing = await client
          .from('trip_requests')
          .select()
          .eq('trip_id', tripId)
          .eq('passenger_id', passengerId)
          .neq('status', 'rejected')
          .limit(1);

      if ((existing as List).isNotEmpty) {
        throw const ServerException(
          'Ya tienes una solicitud activa para este viaje',
        );
      }

      final response = await client
          .from('trip_requests')
          .insert({
            'trip_id': tripId,
            'passenger_id': passengerId,
            'status': 'pending',
            'passenger_count': passengerCount,
            'pickup_note': pickupNote,
            'dropoff_note': dropoffNote,
            'pickup_latitude': pickupLatitude,
            'pickup_longitude': pickupLongitude,
            'dropoff_latitude': dropoffLatitude,
            'dropoff_longitude': dropoffLongitude,
            'request_stops': stops
                .map(
                  (stop) => {
                    'label': stop.label,
                    'latitude': stop.latitude,
                    'longitude': stop.longitude,
                  },
                )
                .toList(),
          })
          .select()
          .single();
      return TripRequestModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<TripRequestModel> updateRequestStatus(
    String requestId,
    String status,
  ) async {
    try {
      final response = await client
          .from('trip_requests')
          .update({'status': status})
          .eq('id', requestId)
          .select()
          .single();
      return TripRequestModel.fromJson(response);
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
      final response = await client
          .from('trip_requests')
          .update({
            'status': 'price_proposed',
            'proposed_price': proposedPrice,
            'price_note': priceNote,
          })
          .eq('id', requestId)
          .select()
          .single();
      return TripRequestModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<TripRequestModel>> getMyRequests(String passengerId) async {
    try {
      final response = await client
          .from('trip_requests')
          .select('*, trips!inner(status)')
          .eq('passenger_id', passengerId)
          .neq('trips.status', 'completed')
          .neq('trips.status', 'cancelled')
          .order('created_at');
      final list = (response as List)
          .map((e) => TripRequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
