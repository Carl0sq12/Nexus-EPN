import '../entities/trip.dart';

/// Abstract repository for trip-related operations.
abstract class TripRepository {
  /// Returns all trips that are currently available with free seats.
  Future<List<Trip>> getAvailableTrips();

  /// Returns trips created by a specific [driverId].
  Future<List<Trip>> getMyTrips(String driverId);

  /// Returns a single trip by its id, regardless of availability.
  Future<Trip> getTripById(String tripId);

  /// Creates a new trip and returns it.
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
    String? routePoints,
  });

  /// Updates specific [fields] for the trip identified by [tripId].
  Future<Trip> updateTrip(String tripId, Map<String, dynamic> fields);

  /// Soft-deletes (cancels) the trip identified by [tripId].
  Future<void> deleteTrip(String tripId);
}
