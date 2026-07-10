import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/rating.dart';
import '../repositories/rating_repository.dart';

/// Parameters for [GetRatingsUseCase].
class GetRatingsParams extends Equatable {
  final String userId;

  const GetRatingsParams({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Use case for retrieving all ratings received by a user.
class GetRatingsUseCase implements UseCase<List<Rating>, GetRatingsParams> {
  final RatingRepository repository;

  const GetRatingsUseCase(this.repository);

  @override
  Future<List<Rating>> call(GetRatingsParams params) {
    return repository.getRatingsForUser(params.userId);
  }
}
