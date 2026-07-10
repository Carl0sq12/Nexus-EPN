import 'package:equatable/equatable.dart';

/// Entity representing a chat message in a trip conversation.
class Message extends Equatable {
  final String id;
  final String tripId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, tripId, senderId, content, createdAt];
}
