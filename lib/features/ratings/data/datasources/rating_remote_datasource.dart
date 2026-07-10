import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/rating_model.dart';

/// Remote datasource for rating operations using Supabase.
class RatingRemoteDatasource {
  final SupabaseClient client;

  const RatingRemoteDatasource(this.client);

  Future<RatingModel> sendRating({
    required String tripId,
    required String raterId,
    required String ratedUserId,
    required int score,
    String? comment,
  }) async {
    try {
      final response = await client
          .from('ratings')
          .insert({
            'trip_id': tripId,
            'rater_id': raterId,
            'rated_user_id': ratedUserId,
            'score': score,
            if (comment != null) 'comment': comment,
          })
          .select()
          .single();
      return RatingModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<RatingModel>> getRatingsForUser(String userId) async {
    try {
      final response = await client
          .from('ratings')
          .select()
          .eq('rated_user_id', userId)
          .order('created_at', ascending: false);
      final list = (response as List)
          .map((e) => RatingModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
