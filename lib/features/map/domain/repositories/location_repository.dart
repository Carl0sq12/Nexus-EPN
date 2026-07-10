import '../entities/user_location.dart';

/// Abstract repository for device location operations.
abstract class LocationRepository {
  /// Returns the current device location.
  Future<UserLocation> getCurrentLocation();
}
