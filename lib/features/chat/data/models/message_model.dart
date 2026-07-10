import '../../domain/entities/message.dart';

/// Data model for [Message] with JSON serialization using Supabase snake_case keys.
class MessageModel extends Message {
  const MessageModel({
    required String id,
    required String tripId,
    required String senderId,
    required String content,
    required DateTime createdAt,
  }) : super(
         id: id,
         tripId: tripId,
         senderId: senderId,
         content: content,
         createdAt: createdAt,
       );

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
