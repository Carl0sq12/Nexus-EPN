import '../entities/rating.dart';

/// Abstract repository for rating operations.
abstract class RatingRepository {
  /// Sends a rating for a trip.
  Future<Rating> sendRating({
    required String tripId,
    required String raterId,
    required String ratedUserId,
    required int score,
    String? comment,
  });

  /// Returns all ratings received by a specific user.
  Future<List<Rating>> getRatingsForUser(String userId);
}
