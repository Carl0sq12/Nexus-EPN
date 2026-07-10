import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

/// Parameters for [SendMessageUseCase].
class SendMessageParams extends Equatable {
  final String tripId;
  final String senderId;
  final String content;

  const SendMessageParams({
    required this.tripId,
    required this.senderId,
    required this.content,
  });

  @override
  List<Object?> get props => [tripId, senderId, content];
}

/// Use case for sending a chat message.
class SendMessageUseCase implements UseCase<Message, SendMessageParams> {
  final ChatRepository repository;

  const SendMessageUseCase(this.repository);

  @override
  Future<Message> call(SendMessageParams params) {
    return repository.sendMessage(
      params.tripId,
      params.senderId,
      params.content,
    );
  }
}
