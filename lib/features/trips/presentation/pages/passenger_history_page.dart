import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../requests/presentation/providers/request_provider.dart';

/// Passenger trip/request history with completed and cancelled statuses.
class PassengerHistoryPage extends ConsumerWidget {
  const PassengerHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final requestsAsync = ref.watch(myRequestsProvider(userId));
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis viajes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: requestsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myRequestsProvider(userId)),
        ),
        data: (requests) {
          final history = requests
              .where(
                (r) =>
                    r.status == AppStrings.statusCompleted ||
                    r.status == AppStrings.statusCancelled ||
                    r.status == AppStrings.statusRejected ||
                    r.status == AppStrings.statusAccepted,
              )
              .toList();
          if (history.isEmpty) {
            return Center(
              child: Text(
                'Aún no tienes historial de viajes',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = history[index];
              final label = _statusLabel(r.status);
              final color = _statusColor(r.status);
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text('Viaje ${r.tripId}', style: AppTextStyles.titleMedium),
                subtitle: Text(
                  '${fmt.format(r.createdAt.toLocal())}\nEstado: $label',
                ),
                isThreeLine: true,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(color: color),
                  ),
                ),
                onTap: () =>
                    context.push('${AppStrings.routeTrips}/${r.tripId}'),
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppStrings.statusCompleted:
        return 'Completado';
      case AppStrings.statusCancelled:
        return 'Cancelado';
      case AppStrings.statusRejected:
        return 'Rechazado';
      case AppStrings.statusAccepted:
        return 'Aceptado';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppStrings.statusCompleted:
        return Colors.green.shade700;
      case AppStrings.statusCancelled:
      case AppStrings.statusRejected:
        return AppColors.error;
      case AppStrings.statusAccepted:
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}
