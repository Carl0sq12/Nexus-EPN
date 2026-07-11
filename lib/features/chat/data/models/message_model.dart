import '../../domain/entities/message.dart';

/// Data model for [Message] with JSON serialization (Appwrite / snake_case).
class MessageModel extends Message {
  const MessageModel({
    required String id,
    required String tripId,
    required String senderId,
    required String content,
    required DateTime createdAt,
    bool isSystem = false,
  }) : super(
         id: id,
         tripId: tripId,
         senderId: senderId,
         content: content,
         createdAt: createdAt,
         isSystem: isSystem,
       );

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json[r'$id']) as String;
    final createdRaw = json['created_at'] ?? json[r'$createdAt'];
    return MessageModel(
      id: id,
      tripId: json['trip_id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      content: json['content'] as String,
      createdAt: DateTime.parse(createdRaw as String),
      isSystem: json['is_system'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_system': isSystem,
    };
  }
}
