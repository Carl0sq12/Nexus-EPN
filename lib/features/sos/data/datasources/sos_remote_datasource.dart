import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../models/sos_alert_model.dart';

/// Remote datasource for SOS emergency alerts using Appwrite Databases.
class SosRemoteDatasource {
  final Databases databases;

  const SosRemoteDatasource(this.databases);

  Future<SosAlertModel> sendSosAlert(
    String userId,
    double latitude,
    double longitude,
    String message,
    String type,
  ) async {
    try {
      final doc = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.collectionSosAlerts,
        documentId: ID.unique(),
        data: {
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'message': message,
          'type': type,
        },
        permissions: ownerPermissions(userId),
      );
      return SosAlertModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
