import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../trips/presentation/providers/trip_provider.dart';
import '../../domain/entities/trip_request.dart';
import '../providers/request_provider.dart';
import 'driver_requests_page.dart';

/// Role-aware requests inbox: drivers see incoming, passengers see their own.
class RequestsInboxPage extends ConsumerWidget {
  const RequestsInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final profileAsync = ref.watch(profileProvider(userId));
    return profileAsync.when(
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (profile) {
        if (profile.role == AppStrings.roleDriver) {
          return const DriverRequestsPage();
        }
        return const _PassengerRequestsPage();
      },
    );
  }
}

class _PassengerRequestsPage extends ConsumerWidget {
  const _PassengerRequestsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final requestsAsync = ref.watch(myRequestsProvider(userId));
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.requestsTitle),
        automaticallyImplyLeading: canPop,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Buscar viajes',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppStrings.routeTripsSearch),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myRequestsProvider(userId)),
        ),
        data: (requests) {
          final visible = requests
              .where(
                (r) =>
                    r.status == AppStrings.statusPending ||
                    r.status == AppStrings.statusPriceProposed ||
                    r.status == AppStrings.statusAccepted ||
                    r.status == AppStrings.statusRejected,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (visible.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send_outlined,
                      size: 56,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no tienes solicitudes de cupo.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () =>
                          context.push(AppStrings.routeTripsSearch),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar un viaje'),
                    ),
                  ],
                ),
              ),
            );
          }

          final pending = visible
              .where(
                (r) =>
                    r.status == AppStrings.statusPending ||
                    r.status == AppStrings.statusPriceProposed,
              )
              .length;
          final accepted = visible
              .where((r) => r.status == AppStrings.statusAccepted)
              .length;
          final rejected = visible
              .where((r) => r.status == AppStrings.statusRejected)
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myRequestsProvider(userId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryChip(
                        label: 'Pendientes',
                        count: pending,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Aceptadas',
                        count: accepted,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryChip(
                        label: 'Rechazadas',
                        count: rejected,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final request in visible) ...[
                  _PassengerRequestCard(request: request),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: AppTextStyles.titleMedium.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerRequestCard extends ConsumerWidget {
  final TripRequest request;

  const _PassengerRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(request.tripId));

    final routeLabel = tripAsync.maybeWhen(
      data: (trip) => '${trip.origin} → ${trip.destination}',
      orElse: () => 'Viaje',
    );
    final timeLabel = tripAsync.maybeWhen(
      data: (trip) => DateFormat('dd/MM HH:mm').format(trip.departureTime),
      orElse: () => DateFormat('dd/MM HH:mm').format(request.createdAt),
    );
    final trip = tripAsync.asData?.value;
    final driverProfile = trip == null
        ? null
        : ref.watch(profileProvider(trip.driverId)).asData?.value;
    final driverName = (driverProfile?.fullName.trim().isNotEmpty ?? false)
        ? driverProfile!.fullName.trim()
        : 'Conductor';
    final statusMsg = _statusMessage(request);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('${AppStrings.routeRequests}/${request.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$driverName, $routeLabel',
                      style: AppTextStyles.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeLabel · ${request.passengerCount} cupo(s) · $statusMsg',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  String _statusMessage(TripRequest request) {
    return switch (request.status) {
      AppStrings.statusAccepted => 'Se aprobó tu cupo',
      AppStrings.statusRejected => 'Se rechazó',
      AppStrings.statusPriceProposed => 'Precio propuesto',
      AppStrings.statusCancelled => 'Cancelada',
      _ => 'Pendiente',
    };
  }
}
