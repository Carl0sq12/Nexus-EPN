import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../providers/trip_provider.dart';

/// Page showing available trips with Coastal Wave card design.
class TripsListPage extends ConsumerWidget {
  const TripsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;
    final profileAsync = userId == null
        ? null
        : ref.watch(profileProvider(userId));
    final isDriver =
        profileAsync?.maybeWhen(
          data: (profile) => profile.role == AppStrings.roleDriver,
          orElse: () => false,
        ) ??
        false;
    final canUseDriverFeatures = ref.watch(driverCanUseDriverFeaturesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Viajes'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        actions: [
          if (canUseDriverFeatures) ...[
            IconButton(
              tooltip: 'Mis viajes',
              icon: const Icon(Icons.assignment_outlined),
              onPressed: () => context.push(AppStrings.routeMyTrips),
            ),
            IconButton(
              tooltip: 'Publicar viaje',
              icon: const Icon(Icons.add),
              onPressed: () => context.push(AppStrings.routeTripsNew),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _RoleLockedHeader(isDriver: isDriver),
          Expanded(
            child: isDriver
                ? _DriverSection(
                    userId: userId,
                    isDriver: isDriver,
                    canUseDriverFeatures: canUseDriverFeatures,
                  )
                : _PassengerTripsList(),
          ),
        ],
      ),
    );
  }
}

class _RoleLockedHeader extends StatelessWidget {
  final bool isDriver;

  const _RoleLockedHeader({required this.isDriver});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isDriver
                ? Icons.directions_car_outlined
                : Icons.person_pin_circle_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDriver
                  ? 'Modo conductor: publica y gestiona tus viajes.'
                  : 'Modo pasajero: busca viajes y solicita cupos.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerTripsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;
    final requestsAsync = userId == null
        ? null
        : ref.watch(myRequestsProvider(userId));

    return ref
        .watch(availableTripsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (trips) {
            if (trips.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (requestsAsync != null) ...[
                    _PassengerRequestsPreview(requestsAsync: requestsAsync),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.directions_car,
                    size: 64,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'No hay viajes disponibles',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length + (requestsAsync == null ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (requestsAsync != null && index == 0) {
                  return _PassengerRequestsPreview(
                    requestsAsync: requestsAsync,
                  );
                }
                final tripIndex = requestsAsync == null ? index : index - 1;
                final trip = trips[tripIndex];
                final time = DateFormat('hh:mm a').format(trip.departureTime);
                final price = '\$${trip.pricePerSeat.toStringAsFixed(2)}';
                final hasActiveRequest = _hasActiveRequestForTrip(
                  requestsAsync,
                  trip.id,
                );

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(13, 111, 148, 0.08),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        trip.origin,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: AppColors.primaryMid,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        trip.destination,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(time, style: AppTextStyles.labelSmall),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC0F2EE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${trip.availableSeats} ${trip.availableSeats == 1 ? 'Asiento' : 'Asientos'}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Route line with stops
                        SizedBox(
                          height: 72,
                          child: Row(
                            children: [
                              // Vertical line with dots
                              SizedBox(
                                width: 28,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              AppColors.primary,
                                              AppColors.primaryMid,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primaryMid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Labels
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.origin,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      trip.destination,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (trip.routeDistanceMeters != null ||
                            trip.routeDurationSeconds != null) ...[
                          Row(
                            children: [
                              if (trip.routeDistanceMeters != null) ...[
                                const Icon(
                                  Icons.route,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(trip.routeDistanceMeters! / 1000).toStringAsFixed(1)} km',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                              if (trip.routeDurationSeconds != null) ...[
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(trip.routeDurationSeconds! / 60).round()} min',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Divider(
                          height: 1,
                          color: AppColors.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Precio base',
                                  style: AppTextStyles.labelSmall,
                                ),
                                Text(price, style: AppTextStyles.titleMedium),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: () => context.push(
                                      hasActiveRequest
                                          ? '/trips/${trip.id}'
                                          : '/trips/${trip.id}/request',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                    ),
                                    child: Text(
                                      hasActiveRequest
                                          ? 'Ver estado'
                                          : 'Solicitar',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.push('/trips/${trip.id}'),
                                  child: const Text('Ver viaje'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
  }

  bool _hasActiveRequestForTrip(
    AsyncValue<List<TripRequest>>? requestsAsync,
    String tripId,
  ) {
    final requests = requestsAsync?.asData?.value ?? const <TripRequest>[];
    return requests.any(
      (request) =>
          request.tripId == tripId &&
          request.status != AppStrings.statusRejected,
    );
  }
}

class _PassengerRequestsPreview extends StatelessWidget {
  final AsyncValue<List<TripRequest>> requestsAsync;

  const _PassengerRequestsPreview({required this.requestsAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(13, 111, 148, 0.08),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mis solicitudes', style: AppTextStyles.titleMedium),
          const SizedBox(height: 10),
          requestsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Text(
              'No se pudieron cargar tus solicitudes. Desliza para actualizar.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            data: (requests) {
              if (requests.isEmpty) {
                return Text(
                  'Cuando solicites un cupo, aquí verás el precio propuesto y el estado.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }
              final recent = [...requests]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                children: recent
                    .take(4)
                    .map((request) => _PassengerRequestTile(request: request))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PassengerRequestTile extends StatelessWidget {
  final TripRequest request;

  const _PassengerRequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.status);
    final proposed = request.proposedPrice;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/trips/${request.tripId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(_statusIcon(request.status), color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.passengerCount} puesto(s) solicitados',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    proposed == null
                        ? _statusText(request.status)
                        : '${_statusText(request.status)} · \$${proposed.toStringAsFixed(2)} por asiento',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  String _statusText(String status) {
    return switch (status) {
      AppStrings.statusAccepted => 'Aceptada',
      AppStrings.statusPriceProposed => 'Precio propuesto',
      AppStrings.statusRejected => 'Rechazada',
      _ => 'Esperando precio',
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      AppStrings.statusAccepted => Icons.check_circle_outline,
      AppStrings.statusPriceProposed => Icons.payments_outlined,
      AppStrings.statusRejected => Icons.cancel_outlined,
      _ => Icons.schedule,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      AppStrings.statusAccepted => AppColors.success,
      AppStrings.statusPriceProposed => AppColors.primary,
      AppStrings.statusRejected => AppColors.error,
      _ => AppColors.warning,
    };
  }
}

class _DriverSection extends ConsumerWidget {
  final String? userId;
  final bool isDriver;
  final bool canUseDriverFeatures;

  const _DriverSection({
    required this.userId,
    required this.isDriver,
    required this.canUseDriverFeatures,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null) {
      return const Center(child: Text('Inicia sesión para gestionar viajes'));
    }

    if (!isDriver || !canUseDriverFeatures) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sección para conductores',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isDriver
                  ? 'Registra tu vehículo con fotografía para publicar viajes y aceptar pasajeros.'
                  : 'Para publicar viajes debes tener rol de conductor y registrar tu vehículo.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => context.push(AppStrings.routeTripsNew),
              icon: const Icon(Icons.add),
              label: const Text('Publicar viaje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppStrings.routeMyTrips),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Mis viajes y solicitudes'),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ref
                .watch(myTripsProvider(userId!))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (trips) {
                    if (trips.isEmpty) {
                      return Center(
                        child: Text(
                          'Aún no has publicado viajes',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: trips.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        return ListTile(
                          tileColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text('${trip.origin} → ${trip.destination}'),
                          subtitle: Text(
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(trip.departureTime),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/trips/${trip.id}'),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
