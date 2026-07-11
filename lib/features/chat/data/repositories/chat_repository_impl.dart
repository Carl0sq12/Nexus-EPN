import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

/// Implementation of [ChatRepository] using Appwrite.
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDatasource remoteDatasource;

  const ChatRepositoryImpl(this.remoteDatasource);

  @override
  Future<List<Message>> getMessagesForTrip(String tripId) async {
    try {
      return await remoteDatasource.getMessagesByTrip(tripId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Message> sendMessage(
    String tripId,
    String senderId,
    String content,
  ) async {
    try {
      return await remoteDatasource.sendMessage(tripId, senderId, content);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Message> sendSystemMessage(String tripId, String content) async {
    try {
      return await remoteDatasource.sendSystemMessage(tripId, content);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<int> deleteMessagesForTrip(String tripId) async {
    try {
      return await remoteDatasource.deleteMessagesForTrip(tripId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<Message>> messagesStream(String tripId) {
    return remoteDatasource.messagesStream(tripId);
  }
}
