import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../ratings/presentation/widgets/rating_dialog.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';

/// In-app navigation view for a driver after starting a trip.
class TripNavigationPage extends ConsumerStatefulWidget {
  final String tripId;

  const TripNavigationPage({required this.tripId, super.key});

  @override
  ConsumerState<TripNavigationPage> createState() => _TripNavigationPageState();
}

class _TripNavigationPageState extends ConsumerState<TripNavigationPage> {
  final MapController _mapController = MapController();
  bool _autoFollowDriver = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;
    final tripState = ref.watch(tripNotifierProvider);

    ref.listen(currentLocationStreamProvider, (previous, next) {
      final location = next.asData?.value;
      if (location == null || !_autoFollowDriver) return;
      final driverPoint = LatLng(location.latitude, location.longitude);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(driverPoint, 16);
      });
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
              final routeStart = driverPoint ?? origin;
              final routeAsync = ref.watch(
                routeInfoProvider(
                  RouteRequest(origin: routeStart, destination: destination),
                ),
              );

              return Stack(
                children: [
                  _NavigationMap(
                    mapController: _mapController,
                    origin: origin,
                    destination: destination,
                    driverPoint: driverPoint,
                    routePoints: routeAsync.asData?.value.points,
                  ),
                  Positioned(
                    right: 16,
                    bottom: 190,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'center_driver',
                          backgroundColor: AppColors.surface,
                          onPressed: driverPoint == null
                              ? null
                              : () {
                                  setState(() => _autoFollowDriver = true);
                                  _mapController.move(driverPoint, 16);
                                },
                          child: const Icon(
                            Icons.my_location,
                            color: AppColors.primary,
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
                                  origin: routeStart,
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

class _NavigationMap extends StatelessWidget {
  final MapController mapController;
  final LatLng origin;
  final LatLng destination;
  final LatLng? driverPoint;
  final List<LatLng>? routePoints;

  const _NavigationMap({
    required this.mapController,
    required this.origin,
    required this.destination,
    required this.driverPoint,
    required this.routePoints,
  });

  @override
  Widget build(BuildContext context) {
    final visibleRoute = routePoints?.isNotEmpty == true
        ? routePoints!
        : [origin, destination];
    final initialCenter = driverPoint ?? origin;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: initialCenter, initialZoom: 14.5),
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
                child: const _MapMarker(
                  icon: Icons.navigation,
                  color: AppColors.success,
                ),
              ),
          ],
        ),
      ],
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
          if (routeError != null || locationError != null) ...[
            const SizedBox(height: 8),
            Text(
              routeError ?? locationError!,
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

Future<void> _finishTrip(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
  String driverId,
) async {
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

  if (context.mounted) context.pop();
}
