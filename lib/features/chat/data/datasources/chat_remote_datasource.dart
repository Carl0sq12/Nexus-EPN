import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/message_model.dart';

/// Remote datasource for chat message operations using Supabase.
class ChatRemoteDatasource {
  final SupabaseClient client;

  ChatRemoteDatasource(this.client);

  Future<List<MessageModel>> getMessagesByTrip(String tripId) async {
    try {
      final response = await client
          .from('messages')
          .select()
          .eq('trip_id', tripId)
          .order('created_at');
      final list = (response as List)
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<MessageModel> sendMessage(
    String tripId,
    String senderId,
    String content,
  ) async {
    try {
      final response = await client
          .from('messages')
          .insert({
            'trip_id': tripId,
            'sender_id': senderId,
            'content': content,
          })
          .select()
          .single();
      return MessageModel.fromJson(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Stream<List<MessageModel>> messagesStream(String tripId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at')
        .map((events) {
          return (events as List)
              .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        });
  }
}
