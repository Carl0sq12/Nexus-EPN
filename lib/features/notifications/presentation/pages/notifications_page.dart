import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const _requestTypes = {
    'trip_request',
    'request_accepted',
    'request_rejected',
    'price_proposed',
    'price_accepted',
    'request_cancelled',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: AppLoadingView(message: 'Cargando sesión...'));
    }

    final async = ref.watch(notificationsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: async.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider(userId)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No tienes notificaciones',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          final fmt = DateFormat('dd/MM/yyyy HH:mm');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = items[index];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  await ref
                      .read(notificationRemoteDatasourceProvider)
                      .delete(n.id);
                  ref.invalidate(notificationsProvider(userId));
                  return true;
                },
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: n.read
                      ? AppColors.surface
                      : AppColors.primary.withValues(alpha: 0.08),
                  leading: Icon(
                    _iconFor(n.type),
                    color: _colorFor(n.type),
                  ),
                  title: Text(n.title, style: AppTextStyles.titleMedium),
                  subtitle: Text(
                    '${n.body}\n${fmt.format(n.createdAt.toLocal())}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Eliminar notificación',
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.textSecondary,
                    onPressed: () async {
                      await ref
                          .read(notificationRemoteDatasourceProvider)
                          .delete(n.id);
                      ref.invalidate(notificationsProvider(userId));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notificación eliminada'),
                        ),
                      );
                    },
                  ),
                  onTap: () => _openNotification(context, ref, userId, n),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'chat' => Icons.chat_bubble_outline,
      'sos' => Icons.sos,
      'request_accepted' => Icons.check_circle_outline,
      'request_rejected' => Icons.cancel_outlined,
      'price_proposed' || 'price_accepted' => Icons.payments_outlined,
      'trip_request' || 'request_cancelled' => Icons.person_pin_circle_outlined,
      _ => Icons.directions_car_outlined,
    };
  }

  Color _colorFor(String type) {
    return switch (type) {
      'sos' || 'request_rejected' => AppColors.error,
      'request_accepted' => AppColors.success,
      _ => AppColors.primary,
    };
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AppNotification n,
  ) async {
    await ref.read(notificationRemoteDatasourceProvider).markRead(n.id);
    ref.invalidate(notificationsProvider(userId));
    if (!context.mounted) return;

    if (n.type == 'chat' && n.relatedId != null) {
      context.push('/chat/${n.relatedId}');
      return;
    }
    if (n.type == 'trip_completed') {
      context.go(AppStrings.routeHome);
      return;
    }
    if (n.type == 'sos') {
      context.push(AppStrings.routeMap);
      return;
    }
    if (_requestTypes.contains(n.type) && n.relatedId != null) {
      final requestId = await _resolveRequestId(ref, userId, n);
      if (!context.mounted) return;
      if (requestId != null) {
        context.push('${AppStrings.routeRequests}/$requestId');
        return;
      }
      context.push('${AppStrings.routeTrips}/${n.relatedId}');
      return;
    }
    if (n.type == 'trip' && n.relatedId != null) {
      context.push('${AppStrings.routeTrips}/${n.relatedId}');
    }
  }

  Future<String?> _resolveRequestId(
    WidgetRef ref,
    String userId,
    AppNotification n,
  ) async {
    final tripId = n.relatedId;
    if (tripId == null) return null;

    final profile = ref.read(profileProvider(userId)).asData?.value;
    final isDriver = profile?.role == AppStrings.roleDriver;

    try {
      if (isDriver) {
        final requests = await ref
            .read(requestRepositoryProvider)
            .getRequestsForTrip(tripId);
        if (requests.isEmpty) return null;
        // Prefer pending/proposed; otherwise most recent.
        final actionable = requests.where(
          (r) =>
              r.status == AppStrings.statusPending ||
              r.status == AppStrings.statusPriceProposed,
        );
        if (actionable.isNotEmpty) return actionable.first.id;
        final sorted = [...requests]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted.first.id;
      }

      final mine = await ref
          .read(requestRepositoryProvider)
          .getMyRequests(userId);
      final match = mine.where((r) => r.tripId == tripId).toList();
      if (match.isEmpty) return null;
      match.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return match.first.id;
    } catch (_) {
      return null;
    }
  }
}
