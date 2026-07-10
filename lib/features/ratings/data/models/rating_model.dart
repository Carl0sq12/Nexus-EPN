import '../../domain/entities/rating.dart';

/// Data model for [Rating] with JSON serialization using Supabase snake_case keys.
class RatingModel extends Rating {
  const RatingModel({
    required String id,
    required String tripId,
    required String raterId,
    required String ratedUserId,
    required int score,
    String? comment,
    required DateTime createdAt,
  }) : super(
         id: id,
         tripId: tripId,
         raterId: raterId,
         ratedUserId: ratedUserId,
         score: score,
         comment: comment,
         createdAt: createdAt,
       );

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      raterId: json['rater_id'] as String,
      ratedUserId: json['rated_user_id'] as String,
      score: json['score'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'rater_id': raterId,
      'rated_user_id': ratedUserId,
      'score': score,
      if (comment != null) 'comment': comment,
    };
  }
}
