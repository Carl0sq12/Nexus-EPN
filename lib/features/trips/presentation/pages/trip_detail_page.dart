import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../ratings/presentation/widgets/rating_dialog.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';

/// Trip detail page showing full info, request button, and driver controls.
class TripDetailPage extends ConsumerWidget {
  final String tripId;

  const TripDetailPage({required this.tripId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;
    final requestState = ref.watch(requestNotifierProvider);
    final tripActionState = ref.watch(tripNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del viaje'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: ref
          .watch(tripByIdProvider(tripId))
          .when(
            loading: () => const LoadingWidget(),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (trip) {
              final formattedDate = DateFormat(
                'dd MMM yyyy \u00b7 HH:mm',
              ).format(trip.departureTime);
              final isOwner = userId == trip.driverId;
              final canComplete =
                  isOwner && trip.status == AppStrings.statusInProgress;
              final canNavigate =
                  isOwner &&
                  trip.originLatitude != null &&
                  trip.originLongitude != null &&
                  trip.destinationLatitude != null &&
                  trip.destinationLongitude != null;
              final ownerRequestsAsync = isOwner
                  ? ref.watch(requestsByTripProvider(trip.id))
                  : null;
              final acceptedRequestsCount =
                  ownerRequestsAsync?.maybeWhen(
                    data: (requests) => requests
                        .where(
                          (request) =>
                              request.status == AppStrings.statusAccepted,
                        )
                        .length,
                    orElse: () => 0,
                  ) ??
                  0;
              final canStart =
                  canNavigate &&
                  acceptedRequestsCount > 0 &&
                  (trip.status == AppStrings.statusActive ||
                      trip.status == AppStrings.statusFull);
              final canShowStartAction =
                  trip.status == AppStrings.statusActive ||
                  trip.status == AppStrings.statusFull;
              final requestForTrip = !isOwner && userId != null
                  ? _requestForTrip(
                      ref.watch(myRequestsProvider(userId)),
                      tripId,
                    )
                  : null;
              final canRequestSeat =
                  trip.status == AppStrings.statusActive &&
                  trip.availableSeats > 0 &&
                  requestForTrip == null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TripInfoCard(trip: trip, formattedDate: formattedDate),
                    if (trip.originLatitude != null &&
                        trip.originLongitude != null &&
                        trip.destinationLatitude != null &&
                        trip.destinationLongitude != null) ...[
                      const SizedBox(height: 16),
                      _TripRouteMap(trip: trip),
                    ],
                    if (isOwner &&
                        (trip.status == AppStrings.statusFull ||
                            trip.availableSeats == 0)) ...[
                      const SizedBox(height: 16),
                      const _RouteReadyBanner(),
                    ],
                    if (trip.status == AppStrings.statusCompleted) ...[
                      const SizedBox(height: 16),
                      const _TripCompletedBanner(),
                    ],
                    const SizedBox(height: 24),
                    if (!isOwner && userId != null) ...[
                      if (requestForTrip != null)
                        _PassengerRequestBanner(
                          request: requestForTrip,
                          passengerId: userId,
                        )
                      else
                        CustomButton(
                          label: requestState.isLoading
                              ? 'Enviando...'
                              : 'Solicitar cupo',
                          onPressed: canRequestSeat && !requestState.isLoading
                              ? () => context.push('/trips/$tripId/request')
                              : null,
                        ),
                    ],
                    if (isOwner) ...[
                      CustomButton(
                        label: 'Gestionar solicitudes',
                        onPressed: () =>
                            context.push('/trips/${trip.id}/requests'),
                      ),
                      const SizedBox(height: 12),
                      if (trip.status == AppStrings.statusInProgress) ...[
                        CustomButton(
                          label: 'Continuar navegación',
                          leadingIcon: Icons.navigation_outlined,
                          onPressed: canNavigate
                              ? () =>
                                    context.push('/trips/${trip.id}/navigation')
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ] else if (canShowStartAction) ...[
                        CustomButton(
                          label: 'Iniciar viaje',
                          leadingIcon: Icons.play_arrow,
                          isLoading: tripActionState.isLoading,
                          onPressed: canStart && !tripActionState.isLoading
                              ? () => _startTrip(context, ref, trip, userId!)
                              : null,
                        ),
                        if (acceptedRequestsCount == 0) ...[
                          const SizedBox(height: 8),
                          const _StartTripHint(),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (canComplete) ...[
                        CustomButton(
                          label: 'Marcar como completado',
                          onPressed: userId == null
                              ? null
                              : () => _completeTripAndRatePassengers(
                                  context,
                                  ref,
                                  trip,
                                  userId,
                                ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      CustomButton(
                        label: 'Editar viaje',
                        isOutlined: true,
                        onPressed: () => context.push(AppStrings.routeTripsNew),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Cancelar viaje'),
                                content: const Text(
                                  '¿Estás seguro de cancelar este viaje?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ref
                                          .read(tripNotifierProvider.notifier)
                                          .deleteTrip(tripId, userId!);
                                    },
                                    child: const Text('Sí, cancelar'),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Cancelar viaje'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
    );
  }
}

TripRequest? _requestForTrip(
  AsyncValue<List<TripRequest>> requestsAsync,
  String tripId,
) {
  return requestsAsync.maybeWhen(
    data: (requests) {
      for (final request in requests) {
        if (request.tripId == tripId &&
            request.status != AppStrings.statusRejected) {
          return request;
        }
      }
      return null;
    },
    orElse: () => null,
  );
}

Future<void> _startTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  String driverId,
) async {
  await ref.read(tripNotifierProvider.notifier).updateTrip(trip.id, driverId, {
    'status': AppStrings.statusInProgress,
  });

  final nextState = ref.read(tripNotifierProvider);
  if (!context.mounted) return;
  if (nextState.hasError) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(nextState.error.toString())));
    return;
  }

  context.push('/trips/${trip.id}/navigation');
}

Future<void> _completeTripAndRatePassengers(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  String driverId,
) async {
  final requests = await ref.read(requestsByTripProvider(trip.id).future);
  final acceptedRequests = requests
      .where((request) => request.status == AppStrings.statusAccepted)
      .toList();

  await ref.read(tripNotifierProvider.notifier).updateTrip(trip.id, driverId, {
    'status': AppStrings.statusCompleted,
  });

  for (final request in acceptedRequests) {
    ref.invalidate(myRequestsProvider(request.passengerId));
    ref.invalidate(pendingDriverRatingsProvider(request.passengerId));
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Viaje marcado como completado')),
  );

  for (final request in acceptedRequests) {
    if (!context.mounted) return;
    final result = await RatingDialog.show(context);
    if (result == null) continue;
    await ref
        .read(ratingNotifierProvider.notifier)
        .sendRating(
          tripId: trip.id,
          raterId: driverId,
          ratedUserId: request.passengerId,
          score: result.score,
          comment: result.comment,
        );
  }

  if (context.mounted && acceptedRequests.isNotEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.ratingSent)));
  }
}

class _TripCompletedBanner extends StatelessWidget {
  const _TripCompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Viaje finalizado',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartTripHint extends StatelessWidget {
  const _StartTripHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Acepta al menos una solicitud para iniciar el viaje.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
      ),
    );
  }
}

class _RouteReadyBanner extends StatelessWidget {
  const _RouteReadyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cupos completos. La ruta ya está lista para iniciar el viaje.',
              style: AppTextStyles.bodyMedium.copyWith(
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

class _PassengerRequestBanner extends ConsumerWidget {
  final TripRequest request;
  final String passengerId;

  const _PassengerRequestBanner({
    required this.request,
    required this.passengerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAccepted = request.status == AppStrings.statusAccepted;
    final hasPrice = request.status == AppStrings.statusPriceProposed;
    final proposedTotal = (request.proposedPrice ?? 0) * request.passengerCount;
    final color = isAccepted
        ? AppColors.success
        : hasPrice
        ? AppColors.primary
        : AppColors.warning;
    final label = isAccepted
        ? 'Solicitud aceptada'
        : hasPrice
        ? request.passengerCount > 1
              ? 'Precio propuesto: \$${request.proposedPrice?.toStringAsFixed(2) ?? '--'} por asiento · total \$${proposedTotal.toStringAsFixed(2)}'
              : 'Precio propuesto: \$${request.proposedPrice?.toStringAsFixed(2) ?? '--'}'
        : 'Solicitud enviada. Esperando precio del conductor';
    final requestState = ref.watch(requestNotifierProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAccepted
                    ? Icons.check_circle_outline
                    : hasPrice
                    ? Icons.payments_outlined
                    : Icons.schedule,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isAccepted)
                TextButton(
                  onPressed: () => context.push('/chat/${request.tripId}'),
                  child: const Text('Chat'),
                ),
            ],
          ),
          if (request.passengerCount > 1 ||
              (request.pickupNote ?? '').trim().isNotEmpty ||
              (request.dropoffNote ?? '').trim().isNotEmpty ||
              (request.priceNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${request.passengerCount} pasajero(s)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if ((request.pickupNote ?? '').trim().isNotEmpty)
              Text(
                'Parada: ${request.pickupNote}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if ((request.dropoffNote ?? '').trim().isNotEmpty)
              Text(
                'Destino/parada final: ${request.dropoffNote}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if ((request.priceNote ?? '').trim().isNotEmpty)
              Text(
                request.priceNote!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
          if (hasPrice) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Aceptar precio',
                    isLoading: requestState.isLoading,
                    onPressed: requestState.isLoading
                        ? null
                        : () async {
                            await ref
                                .read(requestNotifierProvider.notifier)
                                .acceptProposedPrice(
                                  request.id,
                                  request.tripId,
                                  passengerId,
                                );
                            if (!context.mounted) return;
                            final nextState = ref.read(requestNotifierProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  nextState.hasError
                                      ? nextState.error.toString()
                                      : 'Precio aceptado. Cupo reservado.',
                                ),
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    label: 'Rechazar',
                    isOutlined: true,
                    onPressed: requestState.isLoading
                        ? null
                        : () async {
                            await ref
                                .read(requestNotifierProvider.notifier)
                                .rejectRequest(request.id);
                            ref.invalidate(myRequestsProvider(passengerId));
                            ref.invalidate(
                              requestsByTripProvider(request.tripId),
                            );
                            if (!context.mounted) return;
                            final nextState = ref.read(requestNotifierProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  nextState.hasError
                                      ? nextState.error.toString()
                                      : 'Precio rechazado',
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TripRouteMap extends ConsumerWidget {
  final Trip trip;

  const _TripRouteMap({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = LatLng(trip.originLatitude!, trip.originLongitude!);
    final destination = LatLng(
      trip.destinationLatitude!,
      trip.destinationLongitude!,
    );
    final routeAsync = ref.watch(
      routeInfoProvider(RouteRequest(origin: origin, destination: destination)),
    );
    final routeInfo = routeAsync.asData?.value;
    final routePoints = routeInfo?.points.isNotEmpty == true
        ? routeInfo!.points
        : [origin, destination];
    final distanceMeters =
        routeInfo?.distanceMeters ?? trip.routeDistanceMeters;
    final durationSeconds =
        routeInfo?.durationSeconds ?? trip.routeDurationSeconds;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(13, 111, 148, 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(initialCenter: origin, initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nexuscampus.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: AppColors.primary,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: origin,
                        width: 48,
                        height: 48,
                        child: const _RouteMarker(
                          icon: Icons.trip_origin,
                          color: AppColors.primary,
                        ),
                      ),
                      Marker(
                        point: destination,
                        width: 48,
                        height: 48,
                        child: _RouteMarker(
                          icon: Icons.flag,
                          color: AppColors.primaryMid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (trip.routeDistanceMeters != null ||
              trip.routeDurationSeconds != null ||
              routeInfo != null ||
              routeAsync.isLoading ||
              routeAsync.hasError)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (distanceMeters != null) ...[
                        Icon(Icons.route, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${(distanceMeters / 1000).toStringAsFixed(1)} km',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                      if (durationSeconds != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.schedule,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(durationSeconds / 60).round()} min',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                      if (routeAsync.isLoading) ...[
                        const Spacer(),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  if (routeAsync.hasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      'No se pudo cargar la ruta por calles. Mostrando línea directa.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RouteMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

/// Card showing trip route and info with Coastal Wave styling.
class _TripInfoCard extends StatelessWidget {
  final Trip trip;
  final String formattedDate;

  const _TripInfoCard({required this.trip, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _DashedLinePainter(color: AppColors.primaryMid),
                  size: const Size(2, double.infinity),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: const Icon(Icons.flag, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(13, 111, 148, 0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoItem(label: 'Origen', value: trip.origin),
                    const SizedBox(height: 12),
                    _InfoItem(label: 'Destino', value: trip.destination),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(formattedDate, style: AppTextStyles.bodyMedium),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${trip.availableSeats} cupos',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '\$${trip.pricePerSeat.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple label/value pair.
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

/// Paints a dashed vertical line.
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
