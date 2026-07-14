import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/map_tiles.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/utils/geo_fare.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';
import '../utils/trip_completion.dart';

/// Trip detail page showing full info, request button, and driver controls.
class TripDetailPage extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailPage({required this.tripId, super.key});

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  final List<TripRequestStop> _pendingStops = [];
  bool _loadingStopLabel = false;
  int _passengerCount = 1;

  Future<void> _markStopOnRoute(LatLng point, List<LatLng> routePoints) async {
    if (_pendingStops.length >= _passengerCount) {
      showAppSnackBar(
        context,
        title: 'Límite de paradas alcanzado',
        message:
            'Ya marcaste $_passengerCount parada(s). Quita una para cambiarla.',
        type: AppSnackBarType.info,
      );
      return;
    }
    if (routePoints.isEmpty) {
      showAppSnackBar(
        context,
        title: 'Ruta cargando',
        message: 'Espera unos segundos antes de marcar tu parada.',
        type: AppSnackBarType.info,
      );
      return;
    }
    if (!RouteGeometry.isNearRoute(point, routePoints)) {
      showAppSnackBar(
        context,
        title: 'Parada fuera de ruta',
        message: 'Toca sobre la línea azul para marcar tu parada.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final snapped = RouteGeometry.nearestPointOnRoute(point, routePoints);
    setState(() => _loadingStopLabel = true);
    var label =
        'Parada (${snapped.latitude.toStringAsFixed(5)}, ${snapped.longitude.toStringAsFixed(5)})';
    try {
      label = await ref.read(reverseGeocodeProvider(snapped).future);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _pendingStops.add(
        TripRequestStop(
          label: 'Parada ${_pendingStops.length + 1}: $label',
          latitude: snapped.latitude,
          longitude: snapped.longitude,
        ),
      );
      _loadingStopLabel = false;
    });
  }

  Future<void> _sendRequest(Trip trip, String userId) async {
    if (_pendingStops.isEmpty) {
      showAppSnackBar(
        context,
        title: 'Marca tu parada',
        message: 'Primero toca la ruta en el mapa para elegir tu punto.',
        type: AppSnackBarType.warning,
      );
      return;
    }
    if (_pendingStops.length < _passengerCount) {
      showAppSnackBar(
        context,
        title: 'Faltan paradas',
        message:
            'Marca ${_passengerCount - _pendingStops.length} parada(s) más antes de enviar.',
        type: AppSnackBarType.warning,
      );
      return;
    }
    if (_passengerCount > trip.availableSeats) {
      showAppSnackBar(
        context,
        title: 'Cupos insuficientes',
        message: 'Este viaje ya no tiene suficientes asientos disponibles.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final firstStop = _pendingStops.first;
    final lastStop = _pendingStops.last;
    await ref
        .read(requestNotifierProvider.notifier)
        .sendRequest(
          trip.id,
          userId,
          passengerCount: _passengerCount,
          pickupNote: firstStop.label,
          dropoffNote: lastStop.label,
          pickupLatitude: firstStop.latitude,
          pickupLongitude: firstStop.longitude,
          dropoffLatitude: lastStop.latitude,
          dropoffLongitude: lastStop.longitude,
          stops: List<TripRequestStop>.of(_pendingStops),
        );

    if (!mounted) return;
    final state = ref.read(requestNotifierProvider);
    if (state.hasError) {
      showAppSnackBar(
        context,
        title: 'No se envió la solicitud',
        message: state.error.toString(),
        type: AppSnackBarType.error,
      );
      return;
    }
    setState(() {
      _pendingStops.clear();
      _passengerCount = 1;
    });
    showAppSnackBar(
      context,
      title: 'Solicitud enviada',
      message: 'El conductor recibirá tu solicitud y podrá aceptarla.',
      type: AppSnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripId;
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final requestState = ref.watch(requestNotifierProvider);
    final tripActionState = ref.watch(tripNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
              final canPassengerNavigate =
                  !isOwner &&
                  requestForTrip?.status == AppStrings.statusAccepted &&
                  trip.status == AppStrings.statusInProgress &&
                  trip.originLatitude != null &&
                  trip.originLongitude != null &&
                  trip.destinationLatitude != null &&
                  trip.destinationLongitude != null;
              final visibleStops = isOwner
                  ? (ownerRequestsAsync?.asData?.value ?? const <TripRequest>[])
                        .where(
                          (request) =>
                              request.status == AppStrings.statusAccepted,
                        )
                        .expand((request) => request.stops)
                        .toList()
                  : (requestForTrip?.stops.isNotEmpty == true
                        ? requestForTrip!.stops
                        : _pendingStops);

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
                      if (!isOwner && canRequestSeat) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _pendingStops.length < _passengerCount
                                ? 'Toca la línea azul para marcar una parada por cada cupo solicitado.'
                                : 'Paradas marcadas. Ya puedes solicitar el cupo.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _TripRouteMap(
                        trip: trip,
                        stops: visibleStops,
                        canPickStop: !isOwner && canRequestSeat,
                        loadingStopLabel: _loadingStopLabel,
                        onMapTap: !isOwner && canRequestSeat
                            ? (point, routePoints) =>
                                  _markStopOnRoute(point, routePoints)
                            : null,
                      ),
                    ],
                    if (isOwner &&
                        (trip.status == AppStrings.statusFull ||
                            trip.availableSeats == 0)) ...[
                      const SizedBox(height: 16),
                      const _RouteReadyBanner(),
                    ],
                    if (trip.status == AppStrings.statusCompleted) ...[
                      const SizedBox(height: 16),
                      _TripCompletedBanner(
                        tripId: trip.id,
                        showReport: isOwner,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (!isOwner && userId != null) ...[
                      if (requestForTrip != null) ...[
                        _PassengerRequestBanner(
                          request: requestForTrip,
                          passengerId: userId,
                        ),
                        if (canPassengerNavigate) ...[
                          const SizedBox(height: 12),
                          CustomButton(
                            label: 'Ver ruta en vivo',
                            leadingIcon: Icons.navigation_outlined,
                            onPressed: () =>
                                context.push('/trips/${trip.id}/navigation'),
                          ),
                        ],
                      ] else if (canRequestSeat) ...[
                        _PassengerSeatPicker(
                          seats: _passengerCount,
                          maxSeats: trip.availableSeats,
                          pricePerSeat: trip.pricePerSeat,
                          onChanged: (value) {
                            setState(() {
                              _passengerCount = value;
                              if (_pendingStops.length > value) {
                                _pendingStops.removeRange(
                                  value,
                                  _pendingStops.length,
                                );
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_pendingStops.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < _pendingStops.length; i++)
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppColors.primary,
                                        child: Text(
                                          '${i + 1}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _pendingStops[i].label,
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Quitar parada',
                                        onPressed: () => setState(
                                          () => _pendingStops.removeAt(i),
                                        ),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        CustomButton(
                          label: requestState.isLoading
                              ? 'Enviando...'
                              : (_pendingStops.length < _passengerCount
                                    ? 'Marca ${_passengerCount - _pendingStops.length} parada(s) más'
                                    : 'Enviar solicitud'),
                          isLoading: requestState.isLoading,
                          onPressed:
                              !requestState.isLoading &&
                                  _pendingStops.length >= _passengerCount
                              ? () => _sendRequest(trip, userId)
                              : _pendingStops.length < _passengerCount
                              ? () {
                                  showAppSnackBar(
                                    context,
                                    title: 'Faltan paradas',
                                    message:
                                        'Marca ${_passengerCount - _pendingStops.length} parada(s) más en la ruta.',
                                    type: AppSnackBarType.warning,
                                  );
                                }
                              : null,
                        ),
                      ],
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
                              : () => _completeTrip(context, ref, trip, userId),
                        ),
                        const SizedBox(height: 12),
                      ],
                      CustomButton(
                        label: 'Editar viaje',
                        isOutlined: true,
                        onPressed: () =>
                            context.push('/trips/new?edit=$tripId'),
                      ),
                      const SizedBox(height: 12),
                      if (trip.status != AppStrings.statusInProgress &&
                          trip.status != AppStrings.statusCompleted &&
                          trip.status != AppStrings.statusCancelled)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: userId == null
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Cancelar viaje'),
                                        content: const Text(
                                          '¿Estás seguro de cancelar este viaje?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('No'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Sí, cancelar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    final ok = await cancelTripWithCleanup(
                                      ref,
                                      trip: trip,
                                      driverId: userId,
                                    );
                                    if (!context.mounted) return;
                                    showAppSnackBar(
                                      context,
                                      title: ok
                                          ? 'Viaje cancelado'
                                          : 'No se canceló el viaje',
                                      message: ok
                                          ? 'Se avisó a los pasajeros para que busquen otro viaje.'
                                          : (ref
                                                    .read(tripNotifierProvider)
                                                    .error
                                                    ?.toString() ??
                                                'No se pudo cancelar.'),
                                      type: ok
                                          ? AppSnackBarType.info
                                          : AppSnackBarType.error,
                                    );
                                    if (ok) context.go(AppStrings.routeMyTrips);
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
            (request.status == AppStrings.statusPending ||
                request.status == AppStrings.statusAccepted ||
                request.status == AppStrings.statusPriceProposed)) {
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
  String userId,
) async {
  await ref.read(tripNotifierProvider.notifier).updateTrip(trip.id, userId, {
    'status': AppStrings.statusInProgress,
  });
  final state = ref.read(tripNotifierProvider);
  if (!context.mounted) return;
  if (state.hasError) {
    showAppSnackBar(
      context,
      title: 'No se inició el viaje',
      message: state.error.toString(),
      type: AppSnackBarType.error,
    );
    return;
  }
  await _notifyAcceptedPassengersTripStarted(ref, trip);
  if (!context.mounted) return;
  context.push('/trips/${trip.id}/navigation');
}

Future<void> _notifyAcceptedPassengersTripStarted(
  WidgetRef ref,
  Trip trip,
) async {
  try {
    final requests = await ref.read(requestsByTripProvider(trip.id).future);
    final datasource = ref.read(notificationRemoteDatasourceProvider);
    final notifiedPassengerIds = <String>{};
    for (final request in requests) {
      if (request.status != AppStrings.statusAccepted) continue;
      if (!notifiedPassengerIds.add(request.passengerId)) continue;
      try {
        await datasource.create(
          userId: request.passengerId,
          title: 'Viaje iniciado',
          body:
              'El conductor inició la navegación hacia ${trip.destination}. Ya puedes ver la ruta del viaje.',
          type: 'trip_navigation_started',
          relatedId: trip.id,
        );
        ref.invalidate(notificationsProvider(request.passengerId));
      } catch (_) {}
    }
  } catch (_) {
    // La navegación del conductor no debe bloquearse por una notificación.
  }
}

Future<void> _completeTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  String userId,
) async {
  double? distanceHint;
  try {
    final position = await Geolocator.getCurrentPosition();
    final destinationLatitude = trip.destinationLatitude;
    final destinationLongitude = trip.destinationLongitude;
    if (destinationLatitude != null && destinationLongitude != null) {
      final meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        destinationLatitude,
        destinationLongitude,
      );
      if (meters > 200) distanceHint = meters;
    }
  } catch (_) {
    // Si no hay GPS, igual permitimos finalizar con confirmación.
  }

  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Finalizar viaje'),
      content: Text(
        distanceHint == null
            ? '¿Estás seguro de finalizar el viaje?\n\n'
                  'Se marcará como completado y se cerrará el chat con los pasajeros.'
            : '¿Estás seguro de finalizar el viaje?\n\n'
                  'Estás a unos ${distanceHint.round()} m del destino. '
                  'Aun así puedes finalizarlo si ya terminaste el recorrido.\n\n'
                  'Se marcará como completado y se cerrará el chat con los pasajeros.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sí, finalizar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final ok = await completeTripWithCleanup(ref, trip: trip, driverId: userId);
  if (!context.mounted) return;
  if (!ok) {
    final state = ref.read(tripNotifierProvider);
    showAppSnackBar(
      context,
      title: 'No se completó el viaje',
      message: state.error?.toString() ?? 'No se pudo completar.',
      type: AppSnackBarType.error,
    );
    return;
  }
  showAppSnackBar(
    context,
    title: 'Viaje completado',
    message: 'El viaje finalizó correctamente y el chat fue eliminado.',
    type: AppSnackBarType.success,
  );
  context.push('${AppStrings.routeTrips}/${trip.id}/report');
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
    final isBusy = ref.watch(requestNotifierProvider).isLoading;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado de tu solicitud: ${_statusLabel(request.status)}',
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
          ),
          if (request.proposedPrice != null) ...[
            const SizedBox(height: 8),
            Text(
              'Precio propuesto: \$${request.proposedPrice!.toStringAsFixed(2)}',
              style: AppTextStyles.bodyMedium,
            ),
          ],
          if (request.stops.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.stops.first.label, style: AppTextStyles.bodySmall),
          ],
          const SizedBox(height: 12),
          if (request.status == AppStrings.statusPriceProposed)
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Aceptar precio',
                    isLoading: isBusy,
                    onPressed: isBusy
                        ? null
                        : () => ref
                              .read(requestNotifierProvider.notifier)
                              .acceptProposedPrice(
                                request.id,
                                request.tripId,
                                passengerId,
                              ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    label: 'Rechazar',
                    isOutlined: true,
                    onPressed: isBusy
                        ? null
                        : () => ref
                              .read(requestNotifierProvider.notifier)
                              .rejectRequest(
                                request.id,
                                tripId: request.tripId,
                                passengerId: passengerId,
                              ),
                  ),
                ),
              ],
            )
          else if (request.status == AppStrings.statusPending ||
              request.status == AppStrings.statusAccepted)
            CustomButton(
              label: 'Cancelar solicitud',
              isOutlined: true,
              isLoading: isBusy,
              onPressed: isBusy
                  ? null
                  : () async {
                      await ref
                          .read(requestNotifierProvider.notifier)
                          .cancelRequest(
                            request.id,
                            tripId: request.tripId,
                            passengerId: passengerId,
                          );
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
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppStrings.statusAccepted:
        return 'Aceptada';
      case AppStrings.statusPriceProposed:
        return 'Precio propuesto';
      case AppStrings.statusRejected:
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }
}

class _RouteReadyBanner extends StatelessWidget {
  const _RouteReadyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Cupos llenos. Puedes iniciar el viaje cuando estés listo.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _TripCompletedBanner extends StatelessWidget {
  final String tripId;
  final bool showReport;

  const _TripCompletedBanner({required this.tripId, required this.showReport});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este viaje ya fue completado. El chat se eliminó.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
          ),
          if (showReport) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  context.push('${AppStrings.routeTrips}/$tripId/report'),
              child: const Text('Ver reporte'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PassengerSeatPicker extends StatelessWidget {
  final int seats;
  final int maxSeats;
  final double pricePerSeat;
  final ValueChanged<int> onChanged;

  const _PassengerSeatPicker({
    required this.seats,
    required this.maxSeats,
    required this.pricePerSeat,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = pricePerSeat * seats;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(13, 111, 148, 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cupos a solicitar', style: AppTextStyles.labelMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: seats > 1 ? () => onChanged(seats - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$seats', style: AppTextStyles.titleMedium),
              ),
              IconButton.filledTonal(
                onPressed: seats < maxSeats ? () => onChanged(seats + 1) : null,
                icon: const Icon(Icons.add),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${pricePerSeat.toStringAsFixed(2)} / cupo',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    'Total \$${total.toStringAsFixed(2)}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
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
    return Text(
      'Necesitas al menos una solicitud aceptada para iniciar.',
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _TripRouteMap extends ConsumerWidget {
  final Trip trip;
  final List<TripRequestStop> stops;
  final bool canPickStop;
  final bool loadingStopLabel;
  final void Function(LatLng point, List<LatLng> routePoints)? onMapTap;

  const _TripRouteMap({
    required this.trip,
    required this.stops,
    this.canPickStop = false,
    this.loadingStopLabel = false,
    this.onMapTap,
  });

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
    final routePoints = trip.routePoints?.isNotEmpty == true
        ? trip.routePoints!
        : (routeInfo?.points.isNotEmpty == true
              ? routeInfo!.points
              : [origin, destination]);
    final distanceMeters =
        trip.routeDistanceMeters ?? routeInfo?.distanceMeters;
    final durationSeconds =
        trip.routeDurationSeconds ?? routeInfo?.durationSeconds;

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
              height: 240,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: origin,
                  initialZoom: 13,
                  onTap: onMapTap == null
                      ? null
                      : (_, point) => onMapTap!(point, routePoints),
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapTiles.urlTemplate,
                    subdomains: MapTiles.subdomains,
                    userAgentPackageName: MapTiles.userAgentPackageName,
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
                        child: const _RouteMarker(
                          icon: Icons.flag,
                          color: AppColors.primaryMid,
                        ),
                      ),
                      for (final stop in stops)
                        Marker(
                          point: LatLng(stop.latitude, stop.longitude),
                          width: 44,
                          height: 44,
                          child: const _RouteMarker(
                            icon: Icons.person_pin_circle,
                            color: AppColors.success,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (distanceMeters != null) ...[
                      const Icon(
                        Icons.route,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(distanceMeters / 1000).toStringAsFixed(1)} km',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    if (durationSeconds != null) ...[
                      const SizedBox(width: 16),
                      const Icon(
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
                    if (loadingStopLabel || routeAsync.isLoading) ...[
                      const Spacer(),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                if (canPickStop) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Toca la ruta azul para marcar tu parada',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                if (routeAsync.hasError &&
                    (trip.routePoints == null ||
                        trip.routePoints!.isEmpty)) ...[
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

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
              const Icon(Icons.location_on, color: AppColors.primary),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              const Icon(Icons.flag, color: AppColors.primaryMid),
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
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
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
                                const Icon(
                                  Icons.people,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${trip.availableSeats} cupos',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
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
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}
