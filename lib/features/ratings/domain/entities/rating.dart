import 'package:equatable/equatable.dart';

/// Entity representing a user rating for a trip.
class Rating extends Equatable {
  final String id;
  final String tripId;
  final String raterId;
  final String ratedUserId;
  final int score;
  final String? comment;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.tripId,
    required this.raterId,
    required this.ratedUserId,
    required this.score,
    this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    tripId,
    raterId,
    ratedUserId,
    score,
    comment,
    createdAt,
  ];
}
