import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../models/app_notification_model.dart';

class NotificationRemoteDatasource {
  NotificationRemoteDatasource({required Databases databases})
      : _databases = databases;

  final Databases _databases;

  Future<List<AppNotificationModel>> listForUser(String userId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.collectionNotifications,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc(r'$createdAt'),
          Query.limit(50),
        ],
      );
      return result.documents
          .map((d) => AppNotificationModel.fromJson(normalizeDocument(d)))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? e.toString());
    }
  }

  Future<AppNotificationModel> create({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) async {
    try {
      // Cross-user notify: Appwrite only allows document permissions for the
      // current session user (or any/users). Targeting Role.user(recipient)
      // fails with "Permissions must be one of: (any, users, user:<me>, ...)".
      // Access is scoped by the user_id attribute when listing.
      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.collectionNotifications,
        documentId: ID.unique(),
        data: {
          'user_id': userId,
          'title': title,
          'body': body,
          'type': type,
          'read': false,
          if (relatedId != null) 'related_id': relatedId,
        },
        permissions: [
          Permission.read(Role.any()),
          Permission.update(Role.any()),
          Permission.delete(Role.any()),
        ],
      );
      return AppNotificationModel.fromJson(normalizeDocument(doc));
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? e.toString());
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.collectionNotifications,
        documentId: notificationId,
        data: {'read': true},
      );
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? e.toString());
    }
  }

  Future<void> delete(String notificationId) async {
    try {
      await _databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.collectionNotifications,
        documentId: notificationId,
      );
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? e.toString());
    }
  }

  /// Deletes request-related notifications for a trip (passenger or driver).
  Future<int> deleteRelatedToTrip({
    required String userId,
    required String tripId,
  }) async {
    const requestTypes = {
      'trip_request',
      'request_accepted',
      'request_rejected',
      'price_proposed',
      'price_accepted',
      'request_cancelled',
    };
    final items = await listForUser(userId);
    var deleted = 0;
    for (final n in items) {
      if (n.relatedId == tripId && requestTypes.contains(n.type)) {
        await delete(n.id);
        deleted++;
      }
    }
    return deleted;
  }
}
