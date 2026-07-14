import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/map_tiles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../map/domain/entities/user_location.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../ratings/presentation/widgets/rating_dialog.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_location_provider.dart';
import '../providers/trip_provider.dart';
import '../utils/trip_completion.dart';

/// In-app navigation view after a trip starts.
class TripNavigationPage extends ConsumerStatefulWidget {
  final String tripId;

  const TripNavigationPage({required this.tripId, super.key});

  @override
  ConsumerState<TripNavigationPage> createState() => _TripNavigationPageState();
}

class _TripNavigationPageState extends ConsumerState<TripNavigationPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimatedMapController _animatedMapController;
  bool _autoFollowDriver = true;
  DateTime? _lastPublishedLocationAt;
  LatLng? _lastPublishedLocationPoint;
  bool _publishingDriverLocation = false;
  bool _driverLocationPublishWarningShown = false;
  List<TripRequest> _cachedAcceptedRequests = const [];

  // --- Arrival / location-permission tracking ---
  final Set<String> _notifiedStopKeys = {};
  bool _notifiedApproachingDestination = false;
  bool _notifiedArrivedDestination = false;
  bool _locationPromptShown = false;
  String? _arrivalBannerMessage;
  bool _passengerTerminalHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animatedMapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(requestsByTripProvider(widget.tripId));
    ref.invalidate(tripByIdProvider(widget.tripId));
    ref.invalidate(tripLocationStreamProvider(widget.tripId));
    ref.invalidate(currentLocationStreamProvider);
  }

  List<TripRequest> _acceptedRequestsFrom(
    AsyncValue<List<TripRequest>> requestsAsync,
  ) {
    final requests = requestsAsync.asData?.value;
    if (requests == null) return _cachedAcceptedRequests;

    final accepted = requests
        .where((request) => request.status == AppStrings.statusAccepted)
        .toList();
    _cachedAcceptedRequests = accepted;
    return accepted;
  }

  /// Smoothly pans (and optionally zooms/rotates) the camera to [point].
  ///
  /// Pass [heading] (degrees clockwise from north) to enable Maps-style
  /// course-up: the map rotates so travel direction stays at the top.
  void _animateCameraTo(LatLng point, {double? zoom, double? heading}) {
    _animatedMapController.animateTo(
      dest: point,
      zoom: zoom ?? _animatedMapController.mapController.camera.zoom,
      // flutter_map rotation is clockwise; course-up needs the inverse.
      rotation: heading == null ? null : -heading,
    );
  }

  Future<void> _checkArrivals(UserLocation location) async {
    final trip = ref.read(tripByIdProvider(widget.tripId)).asData?.value;
    if (trip == null) return;
    final driverLat = location.latitude;
    final driverLng = location.longitude;

    final accepted = _acceptedRequestsFrom(
      ref.read(requestsByTripProvider(trip.id)),
    );
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

  Future<void> _publishDriverLocation(Trip trip, UserLocation location) async {
    if (trip.status == AppStrings.statusCompleted ||
        trip.status == AppStrings.statusCancelled) {
      return;
    }
    if (_publishingDriverLocation) return;

    final point = LatLng(location.latitude, location.longitude);
    final now = DateTime.now();
    final previousPoint = _lastPublishedLocationPoint;
    final previousAt = _lastPublishedLocationAt;
    final movedMeters = previousPoint == null
        ? double.infinity
        : Geolocator.distanceBetween(
            previousPoint.latitude,
            previousPoint.longitude,
            point.latitude,
            point.longitude,
          );
    final elapsed = previousAt == null
        ? const Duration(days: 1)
        : now.difference(previousAt);

    if (elapsed < const Duration(seconds: 2) && movedMeters < 5) return;

    _publishingDriverLocation = true;
    _lastPublishedLocationAt = now;
    _lastPublishedLocationPoint = point;
    try {
      await ref
          .read(tripLocationDatasourceProvider)
          .upsertLocation(
            tripId: trip.id,
            driverId: trip.driverId,
            location: location,
          );
      _driverLocationPublishWarningShown = false;
    } catch (e) {
      if (mounted && !_driverLocationPublishWarningShown) {
        _driverLocationPublishWarningShown = true;
        showAppSnackBar(
          context,
          title: 'Ubicación en vivo no enviada',
          message: 'Revisa que trip_locations exista en Appwrite. $e',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _publishingDriverLocation = false;
    }
  }

  Future<void> _handlePassengerTripTerminal(Trip trip, String userId) async {
    if (_passengerTerminalHandled) return;
    if (trip.status == AppStrings.statusCancelled) {
      _passengerTerminalHandled = true;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Viaje cancelado'),
          content: const Text(
            'El conductor canceló el viaje. Busca otro conductor.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Buscar viaje'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go(AppStrings.routeTrips);
      return;
    }

    if (trip.status == AppStrings.statusCompleted) {
      _passengerTerminalHandled = true;
      if (!mounted) return;
      showAppSnackBar(
        context,
        title: 'Viaje finalizado',
        message: 'Califica al conductor.',
        type: AppSnackBarType.success,
      );
      final result = await RatingDialog.show(context);
      if (result != null && mounted) {
        await ref
            .read(ratingNotifierProvider.notifier)
            .sendRating(
              tripId: trip.id,
              raterId: userId,
              ratedUserId: trip.driverId,
              score: result.score,
              comment: result.comment,
            );
        ref.invalidate(pendingDriverRatingsProvider(userId));
        if (mounted) {
          final state = ref.read(ratingNotifierProvider);
          showAppSnackBar(
            context,
            title: state.hasError ? 'No se envió' : 'Gracias',
            message: state.hasError
                ? state.error.toString()
                : 'Calificación enviada.',
            type: state.hasError
                ? AppSnackBarType.error
                : AppSnackBarType.success,
          );
        }
      }
      if (!mounted) return;
      context.go(AppStrings.routeHome);
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

    // Passenger: detect cancel/complete even if the driver did it on another phone.
    ref.listen(tripStatusStreamProvider(widget.tripId), (previous, next) {
      final trip = next.asData?.value;
      if (trip == null || userId == null) return;
      if (userId == trip.driverId) return;
      _handlePassengerTripTerminal(trip, userId);
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
              // Refresh snapshot while stream polls for terminal states.
              ref.watch(tripStatusStreamProvider(trip.id));

              final requestsAsync = ref.watch(requestsByTripProvider(trip.id));
              final acceptedRequests = _acceptedRequestsFrom(requestsAsync);
              final isDriver = userId == trip.driverId;
              final passengerRequest = userId == null
                  ? null
                  : _acceptedPassengerRequest(acceptedRequests, userId);

              if (!isDriver && userId != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handlePassengerTripTerminal(trip, userId);
                });
              }

              if (isDriver) {
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
                  _publishDriverLocation(trip, location);
                  if (_autoFollowDriver) {
                    final driverPoint = LatLng(
                      location.latitude,
                      location.longitude,
                    );
                    final heading = _effectiveNavigationHeading(
                      previous: previous?.asData?.value,
                      current: location,
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _animateCameraTo(
                        driverPoint,
                        zoom: 17,
                        heading: heading,
                      );
                    });
                  }
                  _checkArrivals(location);
                });
              } else {
                ref.listen(tripLocationStreamProvider(trip.id), (
                  previous,
                  next,
                ) {
                  final remoteLocation = next.asData?.value?.toUserLocation();
                  if (remoteLocation == null || !_autoFollowDriver) return;
                  final prevRemote = previous?.asData?.value?.toUserLocation();
                  final driverPoint = LatLng(
                    remoteLocation.latitude,
                    remoteLocation.longitude,
                  );
                  final heading = _effectiveNavigationHeading(
                    previous: prevRemote,
                    current: remoteLocation,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _animateCameraTo(
                      driverPoint,
                      zoom: 17,
                      heading: heading,
                    );
                  });
                });
              }
              final waitingForRequests =
                  requestsAsync.isLoading && _cachedAcceptedRequests.isEmpty;
              if (!isDriver && waitingForRequests) {
                return const LoadingWidget();
              }
              if (userId == null || (!isDriver && passengerRequest == null)) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Solo el conductor o un pasajero aceptado puede ver esta navegación.',
                      textAlign: TextAlign.center,
                    ),
                  ),
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

              final locationAsync = isDriver
                  ? ref.watch(currentLocationStreamProvider)
                  : null;
              final liveTripLocationAsync = isDriver
                  ? null
                  : ref.watch(tripLocationStreamProvider(trip.id));
              final driverLocation = isDriver
                  ? locationAsync?.asData?.value
                  : liveTripLocationAsync?.asData?.value?.toUserLocation();
              final driverPoint = driverLocation == null
                  ? null
                  : LatLng(driverLocation.latitude, driverLocation.longitude);
              final driverHeading = _normalizedHeading(driverLocation?.heading);
              // Ruta fija origen→destino para no martillar OSRM en cada GPS tick.
              final routeAsync = ref.watch(
                routeInfoProvider(
                  RouteRequest(origin: origin, destination: destination),
                ),
              );
              final passengerStops = isDriver
                  ? acceptedRequests.expand((request) => request.stops).toList()
                  : passengerRequest!.stops;
              final routePoints = routeAsync.asData?.value.points;
              final baseDistanceMeters =
                  routeAsync.asData?.value.distanceMeters ??
                  trip.routeDistanceMeters;
              final baseDurationSeconds =
                  routeAsync.asData?.value.durationSeconds ??
                  trip.routeDurationSeconds;
              final navigationMetrics = _remainingRouteMetrics(
                driverPoint: driverPoint,
                routePoints: routePoints,
                fallbackDistanceMeters: baseDistanceMeters,
                fallbackDurationSeconds: baseDurationSeconds,
              );

              return Stack(
                children: [
                  _NavigationMap(
                    animatedMapController: _animatedMapController,
                    origin: origin,
                    destination: destination,
                    driverPoint: driverPoint,
                    driverHeading: driverHeading,
                    courseUp: _autoFollowDriver,
                    routePoints: routePoints,
                    passengerStops: passengerStops,
                    onUserGesture: () {
                      // El usuario movió el mapa manualmente: deja de seguir
                      // automáticamente hasta que toque "centrar en mí".
                      if (_autoFollowDriver) {
                        setState(() => _autoFollowDriver = false);
                        _animatedMapController.animateTo(rotation: 0);
                      }
                    },
                  ),
                  if (isDriver)
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
                    bottom: 218,
                    child: Column(
                      children: [
                        _MapControlButton(
                          icon: Icons.refresh,
                          tooltip: 'Actualizar ruta',
                          onPressed: () {
                            ref.invalidate(
                              routeInfoProvider(
                                RouteRequest(
                                  origin: origin,
                                  destination: destination,
                                ),
                              ),
                            );
                            if (isDriver) {
                              ref.invalidate(currentLocationStreamProvider);
                            } else {
                              ref.invalidate(
                                tripLocationStreamProvider(trip.id),
                              );
                            }
                          },
                        ),
                        if (driverPoint != null) ...[
                          const SizedBox(height: 12),
                          _MapControlButton(
                            icon: Icons.my_location,
                            tooltip: 'Centrar ubicación',
                            isActive: _autoFollowDriver,
                            onPressed: () {
                              setState(() => _autoFollowDriver = true);
                              _animateCameraTo(
                                driverPoint,
                                zoom: 17,
                                heading: driverHeading,
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _TripNavigationPanel(
                      trip: trip,
                      routeDistanceMeters: navigationMetrics.distanceMeters,
                      routeDurationSeconds: navigationMetrics.durationSeconds,
                      isDriver: isDriver,
                      locationError: locationAsync?.asError?.error.toString(),
                      liveLocationError: liveTripLocationAsync?.asError?.error
                          .toString(),
                      hasLiveDriverLocation: driverPoint != null,
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
  final bool courseUp;
  final List<LatLng>? routePoints;
  final List<TripRequestStop> passengerStops;
  final VoidCallback onUserGesture;

  const _NavigationMap({
    required this.animatedMapController,
    required this.origin,
    required this.destination,
    required this.driverPoint,
    required this.driverHeading,
    required this.courseUp,
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
          urlTemplate: MapTiles.urlTemplate,
          subdomains: MapTiles.subdomains,
          userAgentPackageName: MapTiles.userAgentPackageName,
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
                  courseUp: courseUp,
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

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: const Color.fromRGBO(13, 111, 148, 0.18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.primary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

/// Driver marker that rotates like Google Maps / Waze:
/// - While moving: faces the GPS travel bearing (turns left/right with the car).
/// - Nearly stopped: falls back to device compass heading.
/// - With [courseUp] (auto-follow): arrow stays pointing up; the map rotates.
class _SmoothDriverMarker extends StatefulWidget {
  final LatLng target;
  final double compassHeading;
  final bool courseUp;

  const _SmoothDriverMarker({
    required this.target,
    required this.compassHeading,
    this.courseUp = false,
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
  double _displayedHeading = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_controller.value);
        _displayedHeading = _lerpAngle(_fromHeading, _toHeading, t);
      });
    _previousPoint = widget.target;
    _toHeading = widget.compassHeading;
    _fromHeading = widget.compassHeading;
    _displayedHeading = widget.compassHeading;
  }

  @override
  void didUpdateWidget(covariant _SmoothDriverMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    final from = _previousPoint ?? oldWidget.target;
    final distance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      widget.target.latitude,
      widget.target.longitude,
    );
    final moved = distance >= 1.2;
    final headingDelta = _shortestAngleDelta(
      oldWidget.compassHeading,
      widget.compassHeading,
    ).abs();
    final compassChanged = headingDelta >= 4;

    if (!moved && !compassChanged && oldWidget.courseUp == widget.courseUp) {
      return;
    }

    _fromHeading = _displayedHeading;

    if (moved) {
      _toHeading = _normalizeBearing(
        Geolocator.bearingBetween(
          from.latitude,
          from.longitude,
          widget.target.latitude,
          widget.target.longitude,
        ),
      );
    } else {
      _toHeading = _normalizeBearing(widget.compassHeading);
    }

    _previousPoint = widget.target;
    if (_shortestAngleDelta(_fromHeading, _toHeading).abs() < 0.5) {
      _displayedHeading = _toHeading;
      return;
    }
    _controller
      ..reset()
      ..forward();
  }

  double _lerpAngle(double a, double b, double t) {
    final diff = _shortestAngleDelta(a, b);
    return _normalizeBearing(a + diff * t);
  }

  double _shortestAngleDelta(double a, double b) {
    var diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
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
        final t = Curves.easeOutCubic.transform(_controller.value);
        final heading = _lerpAngle(_fromHeading, _toHeading, t);
        // Course-up: map already faces travel direction — keep arrow pointing up.
        // North-up (manual pan): rotate arrow by geographic heading.
        final screenDegrees = widget.courseUp ? 0.0 : heading;
        return Transform.rotate(
          angle: screenDegrees * math.pi / 180,
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
  final bool isDriver;
  final String? locationError;
  final String? liveLocationError;
  final bool hasLiveDriverLocation;
  final String? routeError;
  final bool isCompleting;
  final VoidCallback? onFinish;

  const _TripNavigationPanel({
    required this.trip,
    required this.routeDistanceMeters,
    required this.routeDurationSeconds,
    required this.isDriver,
    required this.locationError,
    required this.liveLocationError,
    required this.hasLiveDriverLocation,
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
                  label: '${_formatDistance(routeDistanceMeters!)} restantes',
                ),
              if (routeDistanceMeters != null && routeDurationSeconds != null)
                const SizedBox(width: 8),
              if (routeDurationSeconds != null)
                _MetricChip(
                  icon: Icons.schedule,
                  label: '${_formatDuration(routeDurationSeconds!)} restantes',
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
          ] else if (!isDriver && liveLocationError != null) ...[
            const SizedBox(height: 8),
            Text(
              'No se pudo leer la ubicación en vivo del conductor.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ] else if (!isDriver && !hasLiveDriverLocation) ...[
            const SizedBox(height: 8),
            Text(
              'Esperando la ubicación en vivo del conductor...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isDriver)
            CustomButton(
              label: 'Finalizar viaje',
              isLoading: isCompleting,
              onPressed: onFinish,
            )
          else
            Text(
              'Recibirás avisos cuando el conductor llegue a tu parada y al destino.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

TripRequest? _acceptedPassengerRequest(
  List<TripRequest> requests,
  String userId,
) {
  for (final request in requests) {
    if (request.passengerId == userId &&
        request.status == AppStrings.statusAccepted) {
      return request;
    }
  }
  return null;
}

class _NavigationMetrics {
  final double? distanceMeters;
  final double? durationSeconds;

  const _NavigationMetrics({
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class _RouteProjection {
  final double distanceToRouteMeters;
  final double remainingMeters;

  const _RouteProjection({
    required this.distanceToRouteMeters,
    required this.remainingMeters,
  });
}

_NavigationMetrics _remainingRouteMetrics({
  required LatLng? driverPoint,
  required List<LatLng>? routePoints,
  required double? fallbackDistanceMeters,
  required double? fallbackDurationSeconds,
}) {
  if (driverPoint == null || routePoints == null || routePoints.length < 2) {
    return _NavigationMetrics(
      distanceMeters: fallbackDistanceMeters,
      durationSeconds: fallbackDurationSeconds,
    );
  }

  final totalRouteMeters = _polylineDistance(routePoints);
  if (totalRouteMeters <= 0) {
    return _NavigationMetrics(
      distanceMeters: fallbackDistanceMeters,
      durationSeconds: fallbackDurationSeconds,
    );
  }

  final projection = _nearestRouteProjection(driverPoint, routePoints);
  if (projection == null) {
    return _NavigationMetrics(
      distanceMeters: fallbackDistanceMeters,
      durationSeconds: fallbackDurationSeconds,
    );
  }

  final remainingMeters = projection.remainingMeters.clamp(0, totalRouteMeters);
  final baseDistanceMeters =
      fallbackDistanceMeters != null && fallbackDistanceMeters > 0
      ? fallbackDistanceMeters
      : totalRouteMeters;
  final remainingDurationSeconds =
      fallbackDurationSeconds != null && fallbackDurationSeconds > 0
      ? fallbackDurationSeconds * (remainingMeters / baseDistanceMeters)
      : null;

  return _NavigationMetrics(
    distanceMeters: remainingMeters.toDouble(),
    durationSeconds: remainingDurationSeconds,
  );
}

_RouteProjection? _nearestRouteProjection(
  LatLng point,
  List<LatLng> routePoints,
) {
  if (routePoints.length < 2) return null;

  final segmentLengths = <double>[];
  for (var i = 0; i < routePoints.length - 1; i++) {
    segmentLengths.add(_distanceBetween(routePoints[i], routePoints[i + 1]));
  }

  final distanceAfterSegment = List<double>.filled(segmentLengths.length, 0);
  var suffixDistance = 0.0;
  for (var i = segmentLengths.length - 1; i >= 0; i--) {
    distanceAfterSegment[i] = suffixDistance;
    suffixDistance += segmentLengths[i];
  }

  _RouteProjection? best;
  for (var i = 0; i < routePoints.length - 1; i++) {
    final start = routePoints[i];
    final end = routePoints[i + 1];
    final projected = _projectPointToSegment(point, start, end);
    final distanceToRoute = _distanceBetween(point, projected);
    final remainingMeters =
        _distanceBetween(projected, end) + distanceAfterSegment[i];
    final candidate = _RouteProjection(
      distanceToRouteMeters: distanceToRoute,
      remainingMeters: remainingMeters,
    );
    if (best == null ||
        candidate.distanceToRouteMeters < best.distanceToRouteMeters) {
      best = candidate;
    }
  }
  return best;
}

LatLng _projectPointToSegment(LatLng point, LatLng start, LatLng end) {
  final referenceLatitude =
      (point.latitude + start.latitude + end.latitude) / 3;
  final longitudeScale = math.cos(referenceLatitude * math.pi / 180);
  final startX = start.longitude * longitudeScale;
  final startY = start.latitude;
  final endX = end.longitude * longitudeScale;
  final endY = end.latitude;
  final pointX = point.longitude * longitudeScale;
  final pointY = point.latitude;

  final segmentX = endX - startX;
  final segmentY = endY - startY;
  final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;
  if (segmentLengthSquared == 0) return start;

  final t =
      (((pointX - startX) * segmentX + (pointY - startY) * segmentY) /
              segmentLengthSquared)
          .clamp(0.0, 1.0);

  return LatLng(
    start.latitude + (end.latitude - start.latitude) * t,
    start.longitude + (end.longitude - start.longitude) * t,
  );
}

double _polylineDistance(List<LatLng> points) {
  var meters = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    meters += _distanceBetween(points[i], points[i + 1]);
  }
  return meters;
}

double _distanceBetween(LatLng a, LatLng b) {
  return Geolocator.distanceBetween(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
}

String _formatDistance(double meters) {
  if (meters >= 950) return '${(meters / 1000).toStringAsFixed(1)} km';
  if (meters >= 100) return '${((meters / 10).round() * 10)} m';
  return '${meters.round()} m';
}

String _formatDuration(double seconds) {
  if (seconds <= 0) return '0 min';
  if (seconds < 60) return '<1 min';
  return '${(seconds / 60).ceil()} min';
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

double _normalizeBearing(double bearing) {
  var value = bearing % 360;
  if (value < 0) value += 360;
  return value;
}

/// Heading for course-up navigation (Maps-style).
/// Prefers GPS travel bearing when the vehicle moved; otherwise compass.
double? _effectiveNavigationHeading({
  required UserLocation? previous,
  required UserLocation current,
}) {
  if (previous != null) {
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    if (distance >= 1.2) {
      return _normalizeBearing(
        Geolocator.bearingBetween(
          previous.latitude,
          previous.longitude,
          current.latitude,
          current.longitude,
        ),
      );
    }
  }
  final heading = current.heading;
  if (!heading.isFinite || heading < 0) return null;
  return _normalizedHeading(heading);
}

Future<void> _finishTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  String driverId,
) async {
  final distanceHint = await _destinationDistanceHint(ref, trip);
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

  final ok = await completeTripWithCleanup(ref, trip: trip, driverId: driverId);
  if (!context.mounted) return;
  if (!ok) {
    final nextState = ref.read(tripNotifierProvider);
    showAppSnackBar(
      context,
      title: 'No se completó el viaje',
      message: nextState.error?.toString() ?? 'No se pudo completar.',
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
  context.go('${AppStrings.routeTrips}/${trip.id}/report');
}

/// Optional distance to destination for the confirmation message.
/// Returns null when close (<=200 m), unknown, or location unavailable.
Future<double?> _destinationDistanceHint(WidgetRef ref, Trip trip) async {
  final destinationLatitude = trip.destinationLatitude;
  final destinationLongitude = trip.destinationLongitude;
  if (destinationLatitude == null || destinationLongitude == null) return null;

  try {
    ref.invalidate(currentLocationProvider);
    final location = await ref.read(currentLocationProvider.future);
    final distanceMeters = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      destinationLatitude,
      destinationLongitude,
    );
    if (distanceMeters <= 200) return null;
    return distanceMeters;
  } catch (_) {
    return null;
  }
}
