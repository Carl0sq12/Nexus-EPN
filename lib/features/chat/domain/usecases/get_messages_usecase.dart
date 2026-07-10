import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

/// Parameters for [GetMessagesUseCase].
class GetMessagesParams extends Equatable {
  final String tripId;

  const GetMessagesParams({required this.tripId});

  @override
  List<Object?> get props => [tripId];
}

/// Use case for retrieving all messages in a trip conversation.
class GetMessagesUseCase implements UseCase<List<Message>, GetMessagesParams> {
  final ChatRepository repository;

  const GetMessagesUseCase(this.repository);

  @override
  Future<List<Message>> call(GetMessagesParams params) {
    return repository.getMessagesForTrip(params.tripId);
  }
}
