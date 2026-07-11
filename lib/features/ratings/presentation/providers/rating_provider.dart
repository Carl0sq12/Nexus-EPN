import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../domain/entities/rating.dart';
import '../../domain/usecases/send_rating_usecase.dart';
import '../../domain/usecases/get_ratings_usecase.dart';
import '../../data/datasources/rating_remote_datasource.dart';
import '../../data/repositories/rating_repository_impl.dart';

/// Provider for the rating remote datasource.
final ratingDatasourceProvider = Provider<RatingRemoteDatasource>((ref) {
  return RatingRemoteDatasource(ref.watch(databasesProvider));
});

/// Provider for the rating repository.
final ratingRepositoryProvider = Provider<RatingRepositoryImpl>((ref) {
  return RatingRepositoryImpl(ref.watch(ratingDatasourceProvider));
});

/// Provider for [SendRatingUseCase].
final sendRatingUseCaseProvider = Provider<SendRatingUseCase>((ref) {
  return SendRatingUseCase(ref.watch(ratingRepositoryProvider));
});

/// Provider for [GetRatingsUseCase].
final getRatingsUseCaseProvider = Provider<GetRatingsUseCase>((ref) {
  return GetRatingsUseCase(ref.watch(ratingRepositoryProvider));
});

/// Fetches all ratings received by a given user.
final ratingsForUserProvider = FutureProvider.family<List<Rating>, String>((
  ref,
  userId,
) {
  return ref.read(ratingRepositoryProvider).getRatingsForUser(userId);
});

/// Ratings submitted for a specific trip.
final ratingsForTripProvider = FutureProvider.family<List<Rating>, String>((
  ref,
  tripId,
) {
  return ref.read(ratingRepositoryProvider).getRatingsForTrip(tripId);
});

/// State notifier that manages sending a rating.
class RatingNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  RatingNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> sendRating({
    required String tripId,
    required String raterId,
    required String ratedUserId,
    required int score,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(sendRatingUseCaseProvider)(
        SendRatingParams(
          tripId: tripId,
          raterId: raterId,
          ratedUserId: ratedUserId,
          score: score,
          comment: comment,
        ),
      );
      ref.invalidate(ratingsForUserProvider(ratedUserId));
      ref.invalidate(ratingsForTripProvider(tripId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for [RatingNotifier] that exposes the send rating action.
final ratingNotifierProvider =
    StateNotifierProvider<RatingNotifier, AsyncValue<void>>((ref) {
      return RatingNotifier(ref);
    });
