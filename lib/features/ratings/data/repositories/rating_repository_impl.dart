import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/rating.dart';
import '../../domain/repositories/rating_repository.dart';
import '../datasources/rating_remote_datasource.dart';

/// Implementation of [RatingRepository] using Supabase.
class RatingRepositoryImpl implements RatingRepository {
  final RatingRemoteDatasource remoteDatasource;

  const RatingRepositoryImpl(this.remoteDatasource);

  @override
  Future<Rating> sendRating({
    required String tripId,
    required String raterId,
    required String ratedUserId,
    required int score,
    String? comment,
  }) async {
    try {
      return await remoteDatasource.sendRating(
        tripId: tripId,
        raterId: raterId,
        ratedUserId: ratedUserId,
        score: score,
        comment: comment,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<Rating>> getRatingsForUser(String userId) async {
    try {
      return await remoteDatasource.getRatingsForUser(userId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
