import '../entities/message.dart';

/// Abstract repository for chat message operations.
abstract class ChatRepository {
  /// Returns all messages for a specific trip.
  Future<List<Message>> getMessagesForTrip(String tripId);

  /// Sends a new message in a trip conversation.
  Future<Message> sendMessage(String tripId, String senderId, String content);

  /// Sends a message rendered as a system event.
  Future<Message> sendSystemMessage(String tripId, String content);

  /// Deletes all messages for a completed trip.
  Future<int> deleteMessagesForTrip(String tripId);

  /// Returns a stream that emits the full list of messages for a trip in real time.
  Stream<List<Message>> messagesStream(String tripId);
}
