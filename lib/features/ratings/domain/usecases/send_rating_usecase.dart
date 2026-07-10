import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/rating.dart';
import '../repositories/rating_repository.dart';

/// Parameters for [SendRatingUseCase].
class SendRatingParams extends Equatable {
  final String tripId;
  final String raterId;
  final String ratedUserId;
  final int score;
  final String? comment;

  const SendRatingParams({
    required this.tripId,
    required this.raterId,
    required this.ratedUserId,
    required this.score,
    this.comment,
  });

  @override
  List<Object?> get props => [tripId, raterId, ratedUserId, score, comment];
}

/// Use case for submitting a rating for a trip.
class SendRatingUseCase implements UseCase<Rating, SendRatingParams> {
  final RatingRepository repository;

  const SendRatingUseCase(this.repository);

  @override
  Future<Rating> call(SendRatingParams params) {
    return repository.sendRating(
      tripId: params.tripId,
      raterId: params.raterId,
      ratedUserId: params.ratedUserId,
      score: params.score,
      comment: params.comment,
    );
  }
}
