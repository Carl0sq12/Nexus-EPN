import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../../../core/utils/trip_search.dart';
import '../providers/trip_provider.dart';

/// Page showing available trips with Coastal Wave card design.
class TripsListPage extends ConsumerWidget {
  final String? destinationQuery;

  const TripsListPage({this.destinationQuery, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
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
    final query = destinationQuery?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          query != null && query.isNotEmpty ? 'Viajes a $query' : 'Viajes',
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        actions: [
          if (!isDriver)
            IconButton(
              tooltip: 'Buscar destino',
              icon: const Icon(Icons.search),
              onPressed: () => context.push(AppStrings.routeTripsSearch),
            ),
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
                : _PassengerTripsList(destinationQuery: query),
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
  final String? destinationQuery;

  const _PassengerTripsList({this.destinationQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final requestsAsync = userId == null
        ? null
        : ref.watch(myRequestsProvider(userId));
    final query = destinationQuery?.trim().toLowerCase();

    return ref
        .watch(availableTripsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (allTrips) {
            final trips = filterTripsByDestinationQuery(allTrips, query);

            if (trips.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(availableTripsProvider);
                  if (userId != null) {
                    ref.invalidate(myRequestsProvider(userId));
                  }
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (requestsAsync != null) ...[
                      _PassengerRequestsPreview(requestsAsync: requestsAsync),
                      const SizedBox(height: 24),
                    ],
                    const Icon(
                      Icons.directions_car,
                      size: 64,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        query != null && query.isNotEmpty
                            ? 'No hay viajes hacia ese destino'
                            : 'No hay viajes disponibles',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (query != null && query.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              context.push(AppStrings.routeTripsSearch),
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar otro destino'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(availableTripsProvider);
                if (userId != null) {
                  ref.invalidate(myRequestsProvider(userId));
                }
              },
              child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
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
                final activeRequest = _activeRequestForTrip(
                  requestsAsync,
                  trip.id,
                );
                final driverAsync = ref.watch(profileProvider(trip.driverId));
                final driverName = driverAsync.maybeWhen(
                  data: (profile) => profile.fullName,
                  orElse: () => 'Conductor',
                );

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push('/trips/${trip.id}'),
                    child: Card(
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
                                  Text(
                                    '${trip.origin} → ${trip.destination}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(time, style: AppTextStyles.labelSmall),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Conductor: $driverName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  Text(
                                    'Ubicación aproximada: ${trip.origin}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
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
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 116),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Vertical line with dots
                              SizedBox(
                                width: 28,
                                height: 112,
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
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      trip.destination,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
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
                                  'Precio por asiento',
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
                                    onPressed: activeRequest == null
                                        ? () =>
                                              context.push('/trips/${trip.id}')
                                        : () async {
                                            await ref
                                                .read(
                                                  requestNotifierProvider
                                                      .notifier,
                                                )
                                                .cancelRequest(
                                                  activeRequest.id,
                                                  tripId: trip.id,
                                                  passengerId: userId!,
                                                );
                                            if (!context.mounted) return;
                                            final state = ref.read(
                                              requestNotifierProvider,
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  state.hasError
                                                      ? state.error.toString()
                                                      : 'Solicitud cancelada',
                                                ),
                                              ),
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: activeRequest == null
                                          ? AppColors.primary
                                          : AppColors.error,
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
                                      activeRequest == null
                                          ? 'Solicitar'
                                          : 'Cancelar',
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
                ),
                  ),
                );
              },
            ),
            );
          },
        );
  }

  TripRequest? _activeRequestForTrip(
    AsyncValue<List<TripRequest>>? requestsAsync,
    String tripId,
  ) {
    final requests = requestsAsync?.asData?.value ?? const <TripRequest>[];
    for (final request in requests) {
      if (request.tripId == tripId &&
          (request.status == AppStrings.statusPending ||
              request.status == AppStrings.statusAccepted ||
              request.status == AppStrings.statusPriceProposed)) {
        return request;
      }
    }
    return null;
  }
}

class _PassengerRequestsPreview extends ConsumerWidget {
  final AsyncValue<List<TripRequest>> requestsAsync;

  const _PassengerRequestsPreview({required this.requestsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              final latestAccepted = _latestAcceptedRequest(requests);
              final recent = [...requests]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                children: [
                  if (latestAccepted != null) ...[
                    _AcceptedPassengerTripShortcut(request: latestAccepted),
                    const SizedBox(height: 12),
                  ],
                  ...recent
                      .take(4)
                      .map(
                        (request) => _PassengerRequestTile(request: request),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AcceptedPassengerTripShortcut extends ConsumerWidget {
  final TripRequest request;

  const _AcceptedPassengerTripShortcut({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(request.tripId));

    return tripAsync.when(
      loading: () => const _AcceptedTripLoadingCard(),
      error: (_, _) => _AcceptedTripFallbackCard(request: request),
      data: (trip) {
        // Completed/cancelled trips belong in history, not as active shortcut.
        if (trip.status == AppStrings.statusCompleted ||
            trip.status == AppStrings.statusCancelled) {
          return const SizedBox.shrink();
        }

        final driver = ref.watch(profileProvider(trip.driverId)).asData?.value;
        final driverName = driver?.fullName.trim().isNotEmpty == true
            ? driver!.fullName.trim()
            : 'Conductor';
        final isInProgress = trip.status == AppStrings.statusInProgress;
        final canOpenNavigation =
            trip.originLatitude != null &&
            trip.originLongitude != null &&
            trip.destinationLatitude != null &&
            trip.destinationLongitude != null;
        final actionLabel = isInProgress
            ? 'Ver ruta en vivo'
            : canOpenNavigation
            ? 'Ver ruta del viaje'
            : 'Ver detalle';
        final target = canOpenNavigation
            ? '/trips/${trip.id}/navigation'
            : '/trips/${trip.id}';

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push(target),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(13, 111, 148, 0.18),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInProgress
                            ? Icons.navigation_outlined
                            : Icons.event_available_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isInProgress
                                ? 'Viaje en curso'
                                : 'Último viaje aceptado',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Conductor: $driverName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${trip.origin} → ${trip.destination}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${DateFormat('dd/MM HH:mm').format(trip.departureTime.toLocal())} · ${request.passengerCount} cupo(s)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(target),
                    icon: Icon(
                      canOpenNavigation
                          ? Icons.navigation_outlined
                          : Icons.chevron_right,
                    ),
                    label: Text(actionLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AcceptedTripLoadingCard extends StatelessWidget {
  const _AcceptedTripLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _AcceptedTripFallbackCard extends StatelessWidget {
  final TripRequest request;

  const _AcceptedTripFallbackCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/trips/${request.tripId}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tienes un viaje aceptado. Toca para abrir el detalle.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _PassengerRequestTile extends ConsumerWidget {
  final TripRequest request;

  const _PassengerRequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(request.status);
    final proposed = request.proposedPrice;
    final canCancel =
        request.status == AppStrings.statusPending ||
        request.status == AppStrings.statusAccepted ||
        request.status == AppStrings.statusPriceProposed;
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
            if (canCancel)
              TextButton(
                onPressed: () async {
                  await ref
                      .read(requestNotifierProvider.notifier)
                      .cancelRequest(
                        request.id,
                        tripId: request.tripId,
                        passengerId: request.passengerId,
                      );
                  if (!context.mounted) return;
                  final state = ref.read(requestNotifierProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.hasError
                            ? state.error.toString()
                            : 'Solicitud cancelada',
                      ),
                    ),
                  );
                },
                child: const Text('Cancelar'),
              )
            else
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
      AppStrings.statusCancelled => 'Cancelada',
      _ => 'Esperando precio',
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      AppStrings.statusAccepted => Icons.check_circle_outline,
      AppStrings.statusPriceProposed => Icons.payments_outlined,
      AppStrings.statusRejected => Icons.cancel_outlined,
      AppStrings.statusCancelled => Icons.cancel_outlined,
      _ => Icons.schedule,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      AppStrings.statusAccepted => AppColors.success,
      AppStrings.statusPriceProposed => AppColors.primary,
      AppStrings.statusRejected => AppColors.error,
      AppStrings.statusCancelled => AppColors.error,
      _ => AppColors.warning,
    };
  }
}

TripRequest? _latestAcceptedRequest(List<TripRequest> requests) {
  TripRequest? latest;
  for (final request in requests) {
    if (request.status != AppStrings.statusAccepted) continue;
    if (latest == null || request.createdAt.isAfter(latest.createdAt)) {
      latest = request;
    }
  }
  return latest;
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
