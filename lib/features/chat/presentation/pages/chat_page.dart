import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../trips/presentation/providers/trip_provider.dart';
import '../providers/chat_provider.dart';

/// Chat page for real-time trip conversation.
class ChatPage extends ConsumerStatefulWidget {
  final String tripId;

  const ChatPage({required this.tripId, super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.tripId));
    final participantsAsync =
        ref.watch(chatParticipantsProvider(widget.tripId));
    final tripAsync = ref.watch(tripByIdProvider(widget.tripId));
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final tripCompleted = tripAsync.maybeWhen(
      data: (trip) => trip.status == AppStrings.statusCompleted,
      orElse: () => false,
    );
    final isDriver = tripAsync.maybeWhen(
      data: (trip) => trip.driverId == userId,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.chatTitle),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          participantsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (participants) {
              if (participants.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'En este chat',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final p in participants) ...[
                            Chip(
                              avatar: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.15),
                                child: Text(
                                  p.name.isNotEmpty
                                      ? p.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              label: Text(
                                p.isDriver ? '${p.name} (conductor)' : p.name,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (tripCompleted)
            Material(
              color: AppColors.warning.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDriver
                            ? 'Viaje completado. El chat se eliminó; revisa el reporte.'
                            : 'Viaje completado. Califica al conductor desde Inicio.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    if (isDriver)
                      TextButton(
                        onPressed: () => context.push(
                          '${AppStrings.routeTrips}/${widget.tripId}/report',
                        ),
                        child: const Text('Reporte'),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      tripCompleted
                          ? 'El chat de este viaje ya no está disponible.'
                          : AppStrings.noMessages,
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == userId;

                    if (message.isSystem) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.outlineVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message.content,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    }

                    final previous = index > 0 ? messages[index - 1] : null;
                    final showSenderName = !isMe &&
                        (previous == null ||
                            previous.isSystem ||
                            previous.senderId != message.senderId);

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (showSenderName)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  right: 4,
                                  bottom: 4,
                                ),
                                child: _SenderNameLabel(
                                  senderId: message.senderId,
                                  participants:
                                      participantsAsync.asData?.value,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    isMe ? AppColors.primaryGradient : null,
                                color: isMe ? null : AppColors.primarySoft,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottomRight: isMe
                                      ? Radius.zero
                                      : const Radius.circular(16),
                                ),
                              ),
                              child: Text(
                                message.content,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.onBackground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (!tripCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(13, 111, 148, 0.05),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: AppStrings.messageHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.primarySoft,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(userId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.white,
                        onPressed: () => _sendMessage(userId),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _sendMessage(String? userId) {
    final content = _controller.text.trim();
    if (content.isEmpty || userId == null) return;
    ref
        .read(chatNotifierProvider.notifier)
        .sendMessage(widget.tripId, userId, content);
    _controller.clear();
  }
}

class _SenderNameLabel extends ConsumerWidget {
  final String senderId;
  final List<ChatParticipant>? participants;

  const _SenderNameLabel({
    required this.senderId,
    required this.participants,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? fromParticipants;
    if (participants != null) {
      for (final p in participants!) {
        if (p.userId == senderId) {
          fromParticipants = p.isDriver ? '${p.name} (conductor)' : p.name;
          break;
        }
      }
    }

    final String resolved = fromParticipants ??
        ref.watch(profileProvider(senderId)).maybeWhen<String>(
              data: (profile) {
                final full = profile.fullName.trim();
                return full.isEmpty ? 'Usuario' : full;
              },
              orElse: () => 'Usuario',
            );

    return Text(
      resolved,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
