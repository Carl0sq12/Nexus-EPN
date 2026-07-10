import '../../domain/entities/trip_request.dart';

/// Data model for [TripRequest] with JSON serialization using Supabase snake_case keys.
class TripRequestModel extends TripRequest {
  const TripRequestModel({
    required String id,
    required String tripId,
    required String passengerId,
    required String status,
    int passengerCount = 1,
    String? pickupNote,
    String? dropoffNote,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    List<TripRequestStop> stops = const [],
    double? proposedPrice,
    String? priceNote,
    required DateTime createdAt,
  }) : super(
         id: id,
         tripId: tripId,
         passengerId: passengerId,
         status: status,
         passengerCount: passengerCount,
         pickupNote: pickupNote,
         dropoffNote: dropoffNote,
         pickupLatitude: pickupLatitude,
         pickupLongitude: pickupLongitude,
         dropoffLatitude: dropoffLatitude,
         dropoffLongitude: dropoffLongitude,
         stops: stops,
         proposedPrice: proposedPrice,
         priceNote: priceNote,
         createdAt: createdAt,
       );

  factory TripRequestModel.fromJson(Map<String, dynamic> json) {
    return TripRequestModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      passengerId: json['passenger_id'] as String,
      status: json['status'] as String? ?? 'pending',
      passengerCount: json['passenger_count'] as int? ?? 1,
      pickupNote: json['pickup_note'] as String?,
      dropoffNote: json['dropoff_note'] as String?,
      pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble(),
      dropoffLatitude: (json['dropoff_latitude'] as num?)?.toDouble(),
      dropoffLongitude: (json['dropoff_longitude'] as num?)?.toDouble(),
      stops: _parseStops(json['request_stops']),
      proposedPrice: (json['proposed_price'] as num?)?.toDouble(),
      priceNote: json['price_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'passenger_id': passengerId,
      'status': status,
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
      'proposed_price': proposedPrice,
      'price_note': priceNote,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

List<TripRequestStop> _parseStops(dynamic rawStops) {
  if (rawStops is! List) return const [];
  return rawStops
      .whereType<Map>()
      .map((rawStop) {
        final stop = Map<String, dynamic>.from(rawStop);
        final latitude = (stop['latitude'] as num?)?.toDouble();
        final longitude = (stop['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) return null;
        return TripRequestStop(
          label: stop['label'] as String? ?? 'Parada',
          latitude: latitude,
          longitude: longitude,
        );
      })
      .whereType<TripRequestStop>()
      .toList();
}
