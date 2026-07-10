import '../entities/trip_request.dart';

/// Abstract repository for trip request operations.
abstract class RequestRepository {
  /// Returns all requests for a specific trip.
  Future<List<TripRequest>> getRequestsForTrip(String tripId);

  /// Returns all requests made by a specific passenger.
  Future<List<TripRequest>> getMyRequests(String passengerId);

  /// Creates a new request to join a trip.
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
  });

  /// Sends a custom price proposal from the driver to the passenger.
  Future<TripRequest> proposePrice(
    String requestId,
    String tripId, {
    required double proposedPrice,
    String? priceNote,
  });

  /// Passenger accepts the proposed price and reserves the requested seats.
  Future<TripRequest> acceptProposedPrice(String requestId, String tripId);

  /// Accepts a pending request and decrements available seats.
  Future<TripRequest> acceptRequest(String requestId, String tripId);

  /// Rejects a pending request.
  Future<TripRequest> rejectRequest(String requestId);
}
