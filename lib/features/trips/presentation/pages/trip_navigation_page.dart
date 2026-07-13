import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../map/domain/entities/user_location.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';
import '../utils/trip_completion.dart';

/// In-app navigation view for a driver after starting a trip.
class TripNavigationPage extends ConsumerStatefulWidget {
  final String tripId;

  const TripNavigationPage({required this.tripId, super.key});

  @override
  ConsumerState<TripNavigationPage> createState() => _TripNavigationPageState();
}

class _TripNavigationPageState extends ConsumerState<TripNavigationPage>
    with TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;
  bool _autoFollowDriver = true;

  // --- Arrival / location-permission tracking ---
  final Set<String> _notifiedStopKeys = {};
  bool _notifiedApproachingDestination = false;
  bool _notifiedArrivedDestination = false;
  bool _locationPromptShown = false;
  String? _arrivalBannerMessage;

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    super.dispose();
  }

  /// Smoothly pans (and optionally zooms) the camera to [point], instead of
  /// snapping instantly like a plain [MapController.move] would.
  void _animateCameraTo(LatLng point, {double? zoom}) {
    _animatedMapController.animateTo(
      dest: point,
      zoom: zoom ?? _animatedMapController.mapController.camera.zoom,
    );
  }

  Future<void> _checkArrivals(UserLocation location) async {
    final trip = ref.read(tripByIdProvider(widget.tripId)).asData?.value;
    if (trip == null) return;
    final driverLat = location.latitude;
    final driverLng = location.longitude;

    final requests =
        ref.read(requestsByTripProvider(trip.id)).asData?.value ?? const [];
    final accepted =
        requests.where((r) => r.status == AppStrings.statusAccepted).toList();
    final ds = ref.read(notificationRemoteDatasourceProvider);

    // Paradas de pasajeros aceptados.
    for (final request in accepted) {
      for (var i = 0; i < request.stops.length; i++) {
        final stop = request.stops[i];
        final key = '${request.id}_$i';
        if (_notifiedStopKeys.contains(key)) continue;
        final distance = Geolocator.distanceBetween(
          driverLat,
          driverLng,
          stop.latitude,
          stop.longitude,
        );
        if (distance <= 60) {
          _notifiedStopKeys.add(key);
          try {
            await ds.create(
              userId: request.passengerId,
              title: 'Tu conductor llegó',
              body:
                  'El conductor está en tu punto de recogida. Prepárate para abordar.',
              type: 'trip',
              relatedId: trip.id,
            );
            ref.invalidate(notificationsProvider(request.passengerId));
          } catch (_) {}
          if (mounted) {
            setState(() {
              _arrivalBannerMessage = 'Llegaste a la parada de un pasajero';
            });
          }
        }
      }
    }

    // Destino final.
    final destLat = trip.destinationLatitude;
    final destLng = trip.destinationLongitude;
    if (destLat == null || destLng == null) return;
    final distanceToDestination = Geolocator.distanceBetween(
      driverLat,
      driverLng,
      destLat,
      destLng,
    );

    if (!_notifiedApproachingDestination && distanceToDestination <= 500) {
      _notifiedApproachingDestination = true;
      if (mounted) {
        setState(() {
          _arrivalBannerMessage = 'Estás por llegar a tu destino';
        });
      }
      for (final request in accepted) {
        try {
          await ds.create(
            userId: request.passengerId,
            title: 'Ya casi llegan',
            body: 'El conductor está por llegar a ${trip.destination}.',
            type: 'trip',
            relatedId: trip.id,
          );
          ref.invalidate(notificationsProvider(request.passengerId));
        } catch (_) {}
      }
    }

    if (!_notifiedArrivedDestination && distanceToDestination <= 150) {
      _notifiedArrivedDestination = true;
      if (mounted) {
        setState(() {
          _arrivalBannerMessage = 'Llegaste al destino del viaje';
        });
      }
      for (final request in accepted) {
        try {
          await ds.create(
            userId: request.passengerId,
            title: 'Llegaron al destino',
            body: 'El viaje llegó a ${trip.destination}.',
            type: 'trip',
            relatedId: trip.id,
          );
          ref.invalidate(notificationsProvider(request.passengerId));
        } catch (_) {}
      }
    }
  }

  Future<void> _showLocationPrompt(String error) async {
    if (!mounted) return;
    final serviceDisabled = error.contains('Location services are disabled');
    final permanentlyDenied = error.contains(
      'Location permissions are permanently denied',
    );
    final title = serviceDisabled
        ? 'Activa tu GPS'
        : permanentlyDenied
        ? 'Permiso de ubicación bloqueado'
        : 'Permite tu ubicación';
    final message = serviceDisabled
        ? 'Perdimos tu ubicación en tiempo real. Activa el GPS del dispositivo para continuar la navegación.'
        : permanentlyDenied
        ? 'La app no tiene permiso de ubicación. Actívalo desde los ajustes del sistema para seguir navegando.'
        : 'Necesitamos permiso de ubicación para continuar la navegación de este viaje.';
    final actionLabel = serviceDisabled || permanentlyDenied
        ? 'Abrir ajustes'
        : 'Permitir';

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (accepted != true) return;
    if (serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else if (permanentlyDenied) {
      await Geolocator.openAppSettings();
    }
    ref.invalidate(currentLocationStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final tripState = ref.watch(tripNotifierProvider);

    ref.listen(currentLocationStreamProvider, (previous, next) {
      if (next.hasError) {
        if (!_locationPromptShown) {
          _locationPromptShown = true;
          final errorText = next.error.toString();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLocationPrompt(errorText);
          });
        }
        return;
      }
      _locationPromptShown = false;

      final location = next.asData?.value;
      if (location == null) return;
      if (_autoFollowDriver) {
        final driverPoint = LatLng(location.latitude, location.longitude);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _animateCameraTo(driverPoint, zoom: 16);
        });
      }
      _checkArrivals(location);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Viaje en curso'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: ref
          .watch(tripByIdProvider(widget.tripId))
          .when(
            loading: () => const LoadingWidget(),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (trip) {
              if (userId == null || trip.driverId != userId) {
                return const Center(
                  child: Text('Solo el conductor puede navegar este viaje'),
                );
              }

              final origin = _tripOrigin(trip);
              final destination = _tripDestination(trip);
              if (origin == null || destination == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Este viaje no tiene coordenadas para mostrar la ruta.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final locationAsync = ref.watch(currentLocationStreamProvider);
              final driverPoint = locationAsync.asData == null
                  ? null
                  : LatLng(
                      locationAsync.asData!.value.latitude,
                      locationAsync.asData!.value.longitude,
                    );
              final driverHeading = _normalizedHeading(
                locationAsync.asData?.value.heading,
              );
              // Ruta fija origen→destino para no martillar OSRM en cada GPS tick.
              final routeAsync = ref.watch(
                routeInfoProvider(
                  RouteRequest(origin: origin, destination: destination),
                ),
              );
              final passengerStops = ref
                  .watch(requestsByTripProvider(trip.id))
                  .maybeWhen(
                    data: (requests) => requests
                        .where(
                          (request) =>
                              request.status == AppStrings.statusAccepted,
                        )
                        .expand((request) => request.stops)
                        .toList(),
                    orElse: () => const <TripRequestStop>[],
                  );

              return Stack(
                children: [
                  _NavigationMap(
                    animatedMapController: _animatedMapController,
                    origin: origin,
                    destination: destination,
                    driverPoint: driverPoint,
                    driverHeading: driverHeading,
                    routePoints: routeAsync.asData?.value.points,
                    passengerStops: passengerStops,
                    onUserGesture: () {
                      // El usuario movió el mapa manualmente: deja de seguir
                      // automáticamente hasta que toque "centrar en mí".
                      if (_autoFollowDriver) {
                        setState(() => _autoFollowDriver = false);
                      }
                    },
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _HeadingIndicator(heading: driverHeading),
                  ),
                  if (_arrivalBannerMessage != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 76,
                      child: _ArrivalBanner(
                        message: _arrivalBannerMessage!,
                        onDismiss: () =>
                            setState(() => _arrivalBannerMessage = null),
                      ),
                    ),
                  Positioned(
                    right: 16,
                    bottom: 190,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'center_driver',
                          backgroundColor: _autoFollowDriver
                              ? AppColors.primary
                              : AppColors.surface,
                          onPressed: driverPoint == null
                              ? null
                              : () {
                                  setState(() => _autoFollowDriver = true);
                                  _animateCameraTo(driverPoint, zoom: 16);
                                },
                          child: Icon(
                            Icons.my_location,
                            color: _autoFollowDriver
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton.small(
                          heroTag: 'refresh_route',
                          backgroundColor: AppColors.surface,
                          onPressed: () {
                            ref.invalidate(
                              routeInfoProvider(
                                RouteRequest(
                                  origin: origin,
                                  destination: destination,
                                ),
                              ),
                            );
                            ref.invalidate(currentLocationStreamProvider);
                          },
                          child: const Icon(
                            Icons.refresh,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _TripNavigationPanel(
                      trip: trip,
                      routeDistanceMeters:
                          routeAsync.asData?.value.distanceMeters ??
                          trip.routeDistanceMeters,
                      routeDurationSeconds:
                          routeAsync.asData?.value.durationSeconds ??
                          trip.routeDurationSeconds,
                      locationError: locationAsync.asError?.error.toString(),
                      routeError: routeAsync.asError?.error.toString(),
                      isCompleting: tripState.isLoading,
                      onFinish: tripState.isLoading
                          ? null
                          : () => _finishTrip(context, ref, trip, userId),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _ArrivalBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ArrivalBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.success,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationMap extends StatelessWidget {
  final AnimatedMapController animatedMapController;
  final LatLng origin;
  final LatLng destination;
  final LatLng? driverPoint;
  final double driverHeading;
  final List<LatLng>? routePoints;
  final List<TripRequestStop> passengerStops;
  final VoidCallback onUserGesture;

  const _NavigationMap({
    required this.animatedMapController,
    required this.origin,
    required this.destination,
    required this.driverPoint,
    required this.driverHeading,
    required this.routePoints,
    required this.passengerStops,
    required this.onUserGesture,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRoute = routePoints?.isNotEmpty == true
        ? routePoints!
        : [origin, destination];
    final initialCenter = driverPoint ?? origin;

    return FlutterMap(
      mapController: animatedMapController.mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 14.5,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) onUserGesture();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nexuscampus.app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: visibleRoute,
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
              child: const _MapMarker(
                icon: Icons.trip_origin,
                color: AppColors.primary,
              ),
            ),
            Marker(
              point: destination,
              width: 48,
              height: 48,
              child: const _MapMarker(
                icon: Icons.flag,
                color: AppColors.primaryMid,
              ),
            ),
            if (driverPoint != null)
              Marker(
                point: driverPoint!,
                width: 58,
                height: 58,
                child: _SmoothDriverMarker(
                  target: driverPoint!,
                  compassHeading: driverHeading,
                ),
              ),
            for (final stop in passengerStops)
              Marker(
                point: LatLng(stop.latitude, stop.longitude),
                width: 48,
                height: 48,
                child: const _MapMarker(
                  icon: Icons.person_pin_circle,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Driver marker that smoothly rotates toward the direction of real movement
/// (computed from consecutive GPS fixes) instead of snapping instantly to the
/// raw compass heading, which is unreliable inside a moving vehicle.
class _SmoothDriverMarker extends StatefulWidget {
  final LatLng target;
  final double compassHeading;

  const _SmoothDriverMarker({
    required this.target,
    required this.compassHeading,
  });

  @override
  State<_SmoothDriverMarker> createState() => _SmoothDriverMarkerState();
}

class _SmoothDriverMarkerState extends State<_SmoothDriverMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  LatLng? _previousPoint;
  double _fromHeading = 0;
  double _toHeading = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _previousPoint = widget.target;
    _toHeading = widget.compassHeading;
    _fromHeading = widget.compassHeading;
  }

  @override
  void didUpdateWidget(covariant _SmoothDriverMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target == widget.target) return;

    final from = _previousPoint ?? widget.target;
    final distance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      widget.target.latitude,
      widget.target.longitude,
    );

    _fromHeading = _toHeading;
    // With real movement, orient by the actual bearing traveled (mirrors
    // turns like Waze). At near-zero speed, fall back to the device compass.
    _toHeading = distance > 3
        ? Geolocator.bearingBetween(
            from.latitude,
            from.longitude,
            widget.target.latitude,
            widget.target.longitude,
          )
        : widget.compassHeading;

    _previousPoint = widget.target;
    _controller
      ..reset()
      ..forward();
  }

  double _lerpAngle(double a, double b, double t) {
    var diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final result = (a + diff * t) % 360;
    return result < 0 ? result + 360 : result;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_controller.value);
        final heading = _lerpAngle(_fromHeading, _toHeading, t);
        return Transform.rotate(
          angle: heading * math.pi / 180,
          child: const _MapMarker(
            icon: Icons.navigation,
            color: AppColors.success,
          ),
        );
      },
    );
  }
}

class _TripNavigationPanel extends StatelessWidget {
  final Trip trip;
  final double? routeDistanceMeters;
  final double? routeDurationSeconds;
  final String? locationError;
  final String? routeError;
  final bool isCompleting;
  final VoidCallback? onFinish;

  const _TripNavigationPanel({
    required this.trip,
    required this.routeDistanceMeters,
    required this.routeDurationSeconds,
    required this.locationError,
    required this.routeError,
    required this.isCompleting,
    required this.onFinish,
  });

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
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trip.origin} → ${trip.destination}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (routeDistanceMeters != null)
                _MetricChip(
                  icon: Icons.straighten,
                  label:
                      '${(routeDistanceMeters! / 1000).toStringAsFixed(1)} km',
                ),
              if (routeDistanceMeters != null && routeDurationSeconds != null)
                const SizedBox(width: 8),
              if (routeDurationSeconds != null)
                _MetricChip(
                  icon: Icons.schedule,
                  label: '${(routeDurationSeconds! / 60).round()} min',
                ),
            ],
          ),
          if (routeError != null) ...[
            const SizedBox(height: 8),
            Text(
              'No se pudo actualizar la ruta. Revisa tu conexión de datos.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ] else if (locationError != null) ...[
            const SizedBox(height: 8),
            Text(
              locationError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 14),
          CustomButton(
            label: 'Finalizar viaje',
            isLoading: isCompleting,
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _HeadingIndicator extends StatelessWidget {
  final double heading;

  const _HeadingIndicator({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(13, 111, 148, 0.12), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: heading * math.pi / 180,
            child: const Icon(
              Icons.navigation,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text('${heading.round()}°', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MapMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(13, 111, 148, 0.24),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

LatLng? _tripOrigin(Trip trip) {
  final latitude = trip.originLatitude;
  final longitude = trip.originLongitude;
  if (latitude == null || longitude == null) return null;
  return LatLng(latitude, longitude);
}

LatLng? _tripDestination(Trip trip) {
  final latitude = trip.destinationLatitude;
  final longitude = trip.destinationLongitude;
  if (latitude == null || longitude == null) return null;
  return LatLng(latitude, longitude);
}

double _normalizedHeading(double? heading) {
  if (heading == null || !heading.isFinite || heading < 0) return 0;
  return heading % 360;
}

Future<void> _finishTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  String driverId,
) async {
  if (!await _isNearDestination(context, ref, trip)) return;
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Finalizar viaje'),
      content: const Text('¿Quieres marcar este viaje como completado?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Finalizar'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final ok = await completeTripWithCleanup(
    ref,
    trip: trip,
    driverId: driverId,
  );
  if (!context.mounted) return;
  if (!ok) {
    final nextState = ref.read(tripNotifierProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nextState.error?.toString() ?? 'No se pudo completar'),
      ),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Viaje completado. Chat eliminado.')),
  );
  context.go('${AppStrings.routeTrips}/${trip.id}/report');
}

Future<bool> _isNearDestination(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
) async {
  final destinationLatitude = trip.destinationLatitude;
  final destinationLongitude = trip.destinationLongitude;
  if (destinationLatitude == null || destinationLongitude == null) return false;

  try {
    ref.invalidate(currentLocationProvider);
    final location = await ref.read(currentLocationProvider.future);
    final distanceMeters = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      destinationLatitude,
      destinationLongitude,
    );
    if (distanceMeters <= 200) return true;
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aún estás lejos del destino'),
        content: Text(
          'Debes estar a menos de 200 m para finalizar el viaje. '
          'Distancia actual: ${distanceMeters.round()} m.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return false;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo verificar tu ubicación: $e')),
      );
    }
    return false;
  }
}