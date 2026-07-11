import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Appwrite configuration loaded from `.env`.
class AppwriteConfig {
  AppwriteConfig._();

  static String get endpoint =>
      dotenv.env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';

  static String get projectId => dotenv.env['APPWRITE_PROJECT_ID'] ?? '';

  static String get databaseId =>
      dotenv.env['APPWRITE_DATABASE_ID'] ?? 'nexus_campus';

  static String get bucketAvatars =>
      dotenv.env['APPWRITE_BUCKET_AVATARS'] ?? 'avatars';

  /// Same bucket as avatars on free plan; vehicle files use `vehicles/` prefix.
  static String get bucketVehicles =>
      dotenv.env['APPWRITE_BUCKET_VEHICLES'] ?? 'avatars';

  static const String collectionProfiles = 'profiles';
  static const String collectionTrips = 'trips';
  static const String collectionTripRequests = 'trip_requests';
  static const String collectionVehicles = 'vehicles';
  static const String collectionMessages = 'messages';
  static const String collectionRatings = 'ratings';
  static const String collectionSosAlerts = 'sos_alerts';
  static const String collectionEmergencyContacts = 'emergency_contacts';
  static const String collectionNotifications = 'notifications';

  static void validate() {
    if (projectId.isEmpty) {
      throw Exception('Falta APPWRITE_PROJECT_ID en el archivo .env');
    }
    if (endpoint.isEmpty) {
      throw Exception('Falta APPWRITE_ENDPOINT en el archivo .env');
    }
  }

  /// Public file view URL (requires read permission on the file).
  static String fileViewUrl(String bucketId, String fileId) {
    return '$endpoint/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';
  }
}
