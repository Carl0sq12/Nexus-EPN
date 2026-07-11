import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/appwrite_helpers.dart';
import '../models/rating_model.dart';

/// Remote datasource for rating operations using Appwrite Databases.
class RatingRemoteDatasource {
  final Databases databases;

  const RatingRemoteDatasource(this.databases);

  String get _db => AppwriteConfig.databaseId;
  String get _col => AppwriteConfig.collectionRatings;

  Future<RatingModel> sendRating({
    required String tripId,
    required String raterId,
    required String ratedUserId,
    required int score,
    String? comment,
  }) async {
    if (raterId == ratedUserId) {
      throw const ServerException('No puedes calificarte a ti mismo.');
    }
    try {
      final doc = await databases.createDocument(
        databaseId: _db,
        collectionId: _col,
        documentId: ID.unique(),
        data: {
          'trip_id': tripId,
          'rater_id': raterId,
          'rated_user_id': ratedUserId,
          'score': score,
          if (comment != null) 'comment': comment,
        },
        permissions: ownerPermissions(raterId),
      );
      return RatingModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<RatingModel>> getRatingsForUser(String userId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('rated_user_id', userId),
          Query.orderDesc(r'$createdAt'),
        ],
      );
      return response.documents
          .map((d) => RatingModel.fromJson(normalizeDocument(d)))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<RatingModel>> getRatingsForTrip(String tripId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('trip_id', tripId),
          Query.orderDesc(r'$createdAt'),
        ],
      );
      return response.documents
          .map((d) => RatingModel.fromJson(normalizeDocument(d)))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<bool> hasRating({
    required String tripId,
    required String raterId,
    required String ratedUserId,
  }) async {
    try {
      final response = await databases.listDocuments(
        databaseId: _db,
        collectionId: _col,
        queries: [
          Query.equal('trip_id', tripId),
          Query.equal('rater_id', raterId),
          Query.equal('rated_user_id', ratedUserId),
          Query.limit(1),
        ],
      );
      return response.documents.isNotEmpty;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
