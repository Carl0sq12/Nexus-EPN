import '../entities/sos_alert.dart';

/// Abstract repository for SOS emergency alert operations.
abstract class SosRepository {
  /// Sends an SOS alert with the user's current location.
  Future<SosAlert> sendSosAlert(
    String userId,
    double latitude,
    double longitude,
    String message,
    String type,
  );
}
