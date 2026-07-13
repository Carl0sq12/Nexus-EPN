import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_provider.dart';
import '../../domain/entities/trip_request.dart';
import '../providers/request_provider.dart';

/// Detail of a seat request: route, stop, passengers and final status.
class RequestDetailPage extends ConsumerWidget {
  final String requestId;

  const RequestDetailPage({required this.requestId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(requestByIdProvider(requestId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de solicitud'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: requestAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorView(
          message: _friendlyError(e),
          onRetry: () => ref.invalidate(requestByIdProvider(requestId)),
        ),
        data: (request) {
          final tripAsync = ref.watch(tripByIdProvider(request.tripId));
          final trip = tripAsync.asData?.value;
          final tripLoading = tripAsync.isLoading;
          final tripError = tripAsync.hasError;

          if (tripLoading && trip == null) {
            return const LoadingWidget();
          }

          return _RequestDetailBody(
            request: request,
            trip: trip,
            tripError: tripError,
            userId: userId,
            onRetryTrip: () => ref.invalidate(tripByIdProvider(request.tripId)),
          );
        },
      ),
    );
  }

  static String _friendlyError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('connection') ||
        text.contains('socket') ||
        text.contains('host lookup') ||
        text.contains('failed host') ||
        text.contains('network')) {
      return 'Sin conexión con el servidor. Revisa tu internet e intenta de nuevo.';
    }
    return e.toString();
  }
}

class _RequestDetailBody extends ConsumerWidget {
  final TripRequest request;
  final Trip? trip;
  final bool tripError;
  final String? userId;
  final VoidCallback onRetryTrip;

  const _RequestDetailBody({
    required this.request,
    required this.trip,
    required this.tripError,
    required this.userId,
    required this.onRetryTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPassenger = userId == request.passengerId;
    final otherUserId = trip == null
        ? (isPassenger ? null : request.passengerId)
        : (isPassenger ? trip!.driverId : request.passengerId);
    final otherProfile = otherUserId == null
        ? null
        : ref.watch(profileProvider(otherUserId)).asData?.value;
    final otherName = (otherProfile?.fullName.trim().isNotEmpty ?? false)
        ? otherProfile!.fullName.trim()
        : (isPassenger ? 'Conductor' : 'Pasajero');
    final statusLabel = _statusLabel(request, isPassenger: isPassenger);
    final statusColor = _statusColor(request.status);
    final stopLabel = request.stops.isNotEmpty
        ? request.stops.first.label
              .replaceFirst(RegExp(r'^Tu parada:\s*'), '')
              .trim()
        : (request.pickupNote?.trim().isNotEmpty ?? false)
        ? request.pickupNote!.trim()
        : 'Sin parada indicada';
    final routeLabel = trip == null
        ? 'Ruta no disponible (sin conexión)'
        : '${trip!.origin} → ${trip!.destination}';
    final timeLabel = trip == null
        ? DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt)
        : DateFormat('dd/MM/yyyy HH:mm').format(trip!.departureTime);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (tripError) ...[
          Material(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No se pudo cargar el viaje. Revisa tu conexión.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onBackground,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetryTrip,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPassenger ? 'Conductor' : 'Pasajero',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(otherName, style: AppTextStyles.titleMedium),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.route_outlined,
                label: 'Ruta',
                value: routeLabel,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.place_outlined,
                label: 'Parada / recogida',
                value: stopLabel,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.people_outline,
                label: 'Pasajeros',
                value: '${request.passengerCount} pasajero(s)',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.schedule,
                label: trip == null ? 'Solicitado' : 'Salida',
                value: timeLabel,
              ),
              if (request.proposedPrice != null) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Precio propuesto',
                  value: '\$${request.proposedPrice!.toStringAsFixed(2)}',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (userId != null)
          CustomButton(
            label: 'Eliminar notificación',
            isOutlined: true,
            onPressed: () async {
              final deleted = await ref
                  .read(notificationRemoteDatasourceProvider)
                  .deleteRelatedToTrip(userId: userId!, tripId: request.tripId);
              ref.invalidate(notificationsProvider(userId!));
              if (!context.mounted) return;
              showAppSnackBar(
                context,
                title: deleted > 0
                    ? 'Notificación eliminada'
                    : 'Sin notificaciones',
                message: deleted > 0
                    ? 'La alerta relacionada con este viaje fue eliminada.'
                    : 'No había notificaciones pendientes para este viaje.',
                type: deleted > 0
                    ? AppSnackBarType.success
                    : AppSnackBarType.info,
              );
              if (deleted > 0 && context.canPop()) {
                context.pop();
              }
            },
          ),
        if (isPassenger &&
            (request.status == AppStrings.statusPending ||
                request.status == AppStrings.statusAccepted ||
                request.status == AppStrings.statusPriceProposed)) ...[
          const SizedBox(height: 10),
          CustomButton(
            label: 'Cancelar solicitud',
            isOutlined: true,
            onPressed: () async {
              await ref
                  .read(requestNotifierProvider.notifier)
                  .cancelRequest(
                    request.id,
                    tripId: request.tripId,
                    passengerId: request.passengerId,
                  );
              ref.invalidate(requestByIdProvider(request.id));
              if (!context.mounted) return;
              final state = ref.read(requestNotifierProvider);
              showAppSnackBar(
                context,
                title: state.hasError
                    ? 'No se canceló la solicitud'
                    : 'Solicitud cancelada',
                message: state.hasError
                    ? state.error.toString()
                    : 'Tu solicitud fue retirada correctamente.',
                type: state.hasError
                    ? AppSnackBarType.error
                    : AppSnackBarType.success,
              );
            },
          ),
        ],
        if (!isPassenger &&
            (request.status == AppStrings.statusPending ||
                request.status == AppStrings.statusPriceProposed)) ...[
          const SizedBox(height: 10),
          CustomButton(
            label: 'Gestionar solicitud',
            onPressed: () => context.push(
              '${AppStrings.routeTrips}/${request.tripId}/requests',
            ),
          ),
        ],
        if (trip != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () =>
                context.push('${AppStrings.routeTrips}/${trip!.id}'),
            child: const Text('Ver viaje'),
          ),
        ],
      ],
    );
  }

  String _statusLabel(TripRequest request, {required bool isPassenger}) {
    if (!isPassenger) {
      return switch (request.status) {
        AppStrings.statusAccepted => 'Aceptada',
        AppStrings.statusRejected => 'Rechazada',
        AppStrings.statusPriceProposed => 'Precio propuesto',
        AppStrings.statusCancelled => 'Cancelada',
        _ => 'Pendiente',
      };
    }
    return switch (request.status) {
      AppStrings.statusAccepted => 'Se aprobó tu cupo',
      AppStrings.statusRejected => 'Se rechazó tu solicitud',
      AppStrings.statusPriceProposed => 'Precio propuesto',
      AppStrings.statusCancelled => 'Cancelada',
      _ => 'Pendiente',
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      AppStrings.statusAccepted => AppColors.success,
      AppStrings.statusPriceProposed => AppColors.primary,
      AppStrings.statusRejected => AppColors.error,
      AppStrings.statusCancelled => AppColors.textSecondary,
      _ => AppColors.warning,
    };
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
