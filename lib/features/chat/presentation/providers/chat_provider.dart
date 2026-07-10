import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';

/// Provider for the chat remote datasource.
final chatDatasourceProvider = Provider<ChatRemoteDatasource>((ref) {
  return ChatRemoteDatasource(ref.watch(supabaseClientProvider));
});

/// Provider for the chat repository.
final chatRepositoryProvider = Provider<ChatRepositoryImpl>((ref) {
  return ChatRepositoryImpl(ref.watch(chatDatasourceProvider));
});

/// Provider for [SendMessageUseCase].
final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(ref.watch(chatRepositoryProvider));
});

/// Provider for [GetMessagesUseCase].
final getMessagesUseCaseProvider = Provider<GetMessagesUseCase>((ref) {
  return GetMessagesUseCase(ref.watch(chatRepositoryProvider));
});

/// Provides a real-time stream of the full message list for a given trip.
final chatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  tripId,
) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.messagesStream(tripId);
});

/// State notifier that manages sending a chat message.
class ChatNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ChatNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> sendMessage(
    String tripId,
    String senderId,
    String content,
  ) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(sendMessageUseCaseProvider)(
        SendMessageParams(tripId: tripId, senderId: senderId, content: content),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for [ChatNotifier] that exposes the send message action.
final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<void>>((ref) {
      return ChatNotifier(ref);
    });
