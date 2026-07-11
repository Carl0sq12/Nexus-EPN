import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../../trips/presentation/providers/trip_provider.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';

/// Provider for the chat remote datasource.
final chatDatasourceProvider = Provider<ChatRemoteDatasource>((ref) {
  return ChatRemoteDatasource(
    ref.watch(databasesProvider),
    ref.watch(realtimeProvider),
  );
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
      await _notifyChatParticipants(
        tripId: tripId,
        senderId: senderId,
        content: content,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendSystemMessage(String tripId, String content) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(chatRepositoryProvider).sendSystemMessage(tripId, content);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteChatForTrip(String tripId) async {
    try {
      await ref.read(chatRepositoryProvider).deleteMessagesForTrip(tripId);
      ref.invalidate(chatMessagesProvider(tripId));
    } catch (_) {}
  }

  /// Announces that a passenger joined the trip chat.
  Future<void> announcePassengerJoined({
    required String tripId,
    required String passengerId,
    required String passengerName,
  }) async {
    final name = passengerName.trim().isEmpty ? 'Un pasajero' : passengerName.trim();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendSystemMessage(tripId, '$name ingresó al chat');
      ref.invalidate(chatMessagesProvider(tripId));
      ref.invalidate(chatParticipantsProvider(tripId));
    } catch (_) {}

    try {
      final ds = ref.read(notificationRemoteDatasourceProvider);
      await ds.create(
        userId: passengerId,
        title: 'Ya puedes chatear',
        body: 'Tu cupo fue aceptado. Entra al chat del viaje para coordinar.',
        type: 'chat',
        relatedId: tripId,
      );
      ref.invalidate(notificationsProvider(passengerId));

      final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
      final others = <String>{trip.driverId};
      final requests = await ref
          .read(requestRepositoryProvider)
          .getRequestsForTrip(tripId);
      for (final request in requests) {
        if (request.status == AppStrings.statusAccepted &&
            request.passengerId != passengerId) {
          others.add(request.passengerId);
        }
      }
      for (final userId in others) {
        try {
          await ds.create(
            userId: userId,
            title: 'Nuevo integrante en el chat',
            body: '$name ingresó al chat del viaje.',
            type: 'chat',
            relatedId: tripId,
          );
          ref.invalidate(notificationsProvider(userId));
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Notifies driver and accepted passengers (except sender) about the message.
  Future<void> _notifyChatParticipants({
    required String tripId,
    required String senderId,
    required String content,
  }) async {
    try {
      final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
      final recipientIds = <String>{trip.driverId};

      try {
        final requests = await ref
            .read(requestRepositoryProvider)
            .getRequestsForTrip(tripId);
        for (final request in requests) {
          if (request.status == AppStrings.statusAccepted) {
            recipientIds.add(request.passengerId);
          }
        }
      } catch (_) {}

      recipientIds.remove(senderId);
      if (recipientIds.isEmpty) return;

      String senderName = 'Alguien';
      try {
        final profile = await ref.read(profileProvider(senderId).future);
        final name = profile.fullName.trim();
        if (name.isNotEmpty) senderName = name;
      } catch (_) {}

      final preview = content.trim();
      final body = preview.length > 120
          ? '${preview.substring(0, 117)}...'
          : preview;
      final title = 'Mensaje de $senderName';
      final ds = ref.read(notificationRemoteDatasourceProvider);

      for (final recipientId in recipientIds) {
        try {
          await ds.create(
            userId: recipientId,
            title: title,
            body: body.isEmpty ? 'Tienes un mensaje nuevo' : body,
            type: 'chat',
            relatedId: tripId,
          );
          ref.invalidate(notificationsProvider(recipientId));
        } catch (_) {
          // Best-effort: message already sent.
        }
      }
    } catch (_) {
      // Best-effort: message already sent.
    }
  }
}

/// Provider for [ChatNotifier] that exposes the send message action.
final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<void>>((ref) {
      return ChatNotifier(ref);
    });

class ChatParticipant {
  final String userId;
  final String name;
  final bool isDriver;

  const ChatParticipant({
    required this.userId,
    required this.name,
    required this.isDriver,
  });
}

/// Driver + accepted passengers for a trip chat.
final chatParticipantsProvider =
    FutureProvider.family<List<ChatParticipant>, String>((ref, tripId) async {
  final trip = await ref.watch(tripByIdProvider(tripId).future);
  final requests =
      await ref.read(requestRepositoryProvider).getRequestsForTrip(tripId);
  final accepted = requests
      .where((r) => r.status == AppStrings.statusAccepted)
      .toList();

  Future<ChatParticipant> load(String userId, {required bool isDriver}) async {
    var name = isDriver ? 'Conductor' : 'Pasajero';
    try {
      final profile = await ref.read(profileProvider(userId).future);
      final full = profile.fullName.trim();
      if (full.isNotEmpty) name = full;
    } catch (_) {}
    return ChatParticipant(userId: userId, name: name, isDriver: isDriver);
  }

  final participants = <ChatParticipant>[
    await load(trip.driverId, isDriver: true),
  ];
  for (final request in accepted) {
    participants.add(await load(request.passengerId, isDriver: false));
  }
  return participants;
});
