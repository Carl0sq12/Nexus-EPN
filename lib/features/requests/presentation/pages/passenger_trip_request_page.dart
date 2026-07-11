import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/utils/geo_fare.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../map/domain/entities/route_info.dart';
import '../../../map/domain/entities/user_location.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_provider.dart';
import '../../domain/entities/trip_request.dart';
import '../providers/request_provider.dart';

class PassengerTripRequestPage extends ConsumerStatefulWidget {
  final String tripId;
  final TripRequestStop? initialStop;

  const PassengerTripRequestPage({
    required this.tripId,
    this.initialStop,
    super.key,
  });

  @override
  ConsumerState<PassengerTripRequestPage> createState() =>
      _PassengerTripRequestPageState();
}

class _PassengerTripRequestPageState
    extends ConsumerState<PassengerTripRequestPage> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  int _passengerCount = 1;
  bool _loadingLabel = false;
  final List<TripRequestStop> _stops = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStop;
    if (initial != null) {
      _stops.add(initial);
      _pickupController.text = initial.label;
      _dropoffController.text = initial.label;
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    super.dispose();
  }

  Future<void> _setStopPoint(LatLng point, List<LatLng> routePoints) async {
    if (!RouteGeometry.isNearRoute(point, routePoints)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solo puedes marcar paradas sobre la ruta del conductor',
          ),
        ),
      );
      return;
    }
    final snappedPoint = RouteGeometry.nearestPointOnRoute(point, routePoints);
    setState(() {
      _loadingLabel = true;
    });

    final fallback =
        'Punto marcado (${snappedPoint.latitude.toStringAsFixed(5)}, ${snappedPoint.longitude.toStringAsFixed(5)})';
    var label = fallback;
    try {
      label = await ref.read(reverseGeocodeProvider(snappedPoint).future);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _stops
            ..clear()
            ..add(
              TripRequestStop(
                label: 'Tu parada: $label',
                latitude: snappedPoint.latitude,
                longitude: snappedPoint.longitude,
              ),
            );
          _syncLegacyStopFields();
          _loadingLabel = false;
        });
      }
    }
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      _syncLegacyStopFields();
    });
  }

  void _syncLegacyStopFields() {
    if (_stops.isEmpty) {
      _pickupController.clear();
      _dropoffController.clear();
      return;
    }
    _pickupController.text = _stops.first.label;
    _dropoffController.text = _stops.last.label;
  }

  Future<void> _submit(Trip trip, String passengerId) async {
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca al menos una parada en el mapa')),
      );
      return;
    }
    if (_passengerCount > trip.availableSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay suficientes cupos disponibles')),
      );
      return;
    }

    final firstStop = _stops.first;
    final lastStop = _stops.last;
    await ref
        .read(requestNotifierProvider.notifier)
        .sendRequest(
          trip.id,
          passengerId,
          passengerCount: _passengerCount,
          pickupNote: firstStop.label,
          dropoffNote: lastStop.label,
          pickupLatitude: firstStop.latitude,
          pickupLongitude: firstStop.longitude,
          dropoffLatitude: lastStop.latitude,
          dropoffLongitude: lastStop.longitude,
          stops: _stops,
        );

    final state = ref.read(requestNotifierProvider);
    if (!mounted) return;
    if (state.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error.toString())));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada al conductor')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final requestState = ref.watch(requestNotifierProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Solicitar viaje'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: ref
          .watch(tripByIdProvider(widget.tripId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (trip) {
              final tripOrigin =
                  trip.originLatitude != null && trip.originLongitude != null
                  ? LatLng(trip.originLatitude!, trip.originLongitude!)
                  : null;
              final tripDestination =
                  trip.destinationLatitude != null &&
                      trip.destinationLongitude != null
                  ? LatLng(
                      trip.destinationLatitude!,
                      trip.destinationLongitude!,
                    )
                  : null;
              final routeAsync = tripOrigin != null && tripDestination != null
                  ? ref.watch(
                      routeInfoProvider(
                        RouteRequest(
                          origin: tripOrigin,
                          destination: tripDestination,
                        ),
                      ),
                    )
                  : const AsyncValue<RouteInfo?>.data(null);
              final routePoints = trip.routePoints?.isNotEmpty == true
                  ? trip.routePoints!
                  : routeAsync.asData?.value?.points ?? const <LatLng>[];
              final visibleRouteInfo = routePoints.isEmpty
                  ? routeAsync.asData?.value
                  : RouteInfo(
                      points: routePoints,
                      distanceMeters:
                          routeAsync.asData?.value?.distanceMeters ??
                          trip.routeDistanceMeters ??
                          0,
                      durationSeconds:
                          routeAsync.asData?.value?.durationSeconds ??
                          trip.routeDurationSeconds ??
                          0,
                    );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TripHeader(trip: trip),
                    const SizedBox(height: 12),
                    _SeatsCard(
                      seats: _passengerCount,
                      maxSeats: trip.availableSeats,
                      onChanged: (value) =>
                          setState(() => _passengerCount = value),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.touch_app_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Antes de solicitar, toca el mapa sobre la ruta del conductor para marcar tu parada. '
                              'Esa ubicación se enviará al conductor para que apruebe o rechace.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StopField(
                      icon: Icons.flag_outlined,
                      label: 'TU PARADA',
                      controller: _dropoffController,
                    ),
                    if (_stops.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _StopsListCard(stops: _stops, onRemove: _removeStop),
                    ],
                    const SizedBox(height: 12),
                    _StopsMapCard(
                      locationAsync: locationAsync,
                      routeInfo: visibleRouteInfo,
                      tripOrigin: tripOrigin,
                      tripDestination: tripDestination,
                      stops: _stops,
                      loadingLabel: _loadingLabel,
                      onMapTap: (point) => _setStopPoint(point, routePoints),
                    ),
                  ],
                ),
              );
            },
          ),
      bottomNavigationBar: ref
          .watch(tripByIdProvider(widget.tripId))
          .maybeWhen(
            data: (trip) => Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.background],
                ),
              ),
              child: SafeArea(
                top: false,
                child: CustomButton(
                  label: _stops.isEmpty
                      ? 'Marca tu parada para continuar'
                      : 'Enviar solicitud',
                  isLoading: requestState.isLoading,
                  onPressed: userId == null ||
                          requestState.isLoading ||
                          _stops.isEmpty
                      ? null
                      : () => _submit(trip, userId),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  final Trip trip;

  const _TripHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          Text('Viaje seleccionado', style: AppTextStyles.labelSmall),
          const SizedBox(height: 6),
          Text(
            '${trip.origin} → ${trip.destination}',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${trip.availableSeats} cupos disponibles · precio base \$${trip.pricePerSeat.toStringAsFixed(2)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatsCard extends StatelessWidget {
  final int seats;
  final int maxSeats;
  final ValueChanged<int> onChanged;

  const _SeatsCard({
    required this.seats,
    required this.maxSeats,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = maxSeats < 1 ? 1 : maxSeats;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Puestos requeridos', style: AppTextStyles.titleMedium),
          ),
          IconButton.filledTonal(
            onPressed: seats <= 1 ? null : () => onChanged(seats - 1),
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$seats', style: AppTextStyles.titleLarge),
          ),
          IconButton.filledTonal(
            onPressed: seats >= safeMax ? null : () => onChanged(seats + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _StopField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;

  const _StopField({
    required this.icon,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                hintText: 'Marca el punto en el mapa',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopsListCard extends StatelessWidget {
  final List<TripRequestStop> stops;
  final ValueChanged<int> onRemove;

  const _StopsListCard({required this.stops, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PARADAS MARCADAS', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < stops.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Text(
                  '${i + 1}',
                  style: AppTextStyles.caption.copyWith(color: Colors.white),
                ),
              ),
              title: Text(
                stops[i].label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall,
              ),
              trailing: IconButton(
                tooltip: 'Quitar parada',
                icon: const Icon(Icons.close),
                onPressed: () => onRemove(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _StopsMapCard extends StatelessWidget {
  final AsyncValue<UserLocation> locationAsync;
  final RouteInfo? routeInfo;
  final LatLng? tripOrigin;
  final LatLng? tripDestination;
  final List<TripRequestStop> stops;
  final bool loadingLabel;
  final ValueChanged<LatLng> onMapTap;

  const _StopsMapCard({
    required this.locationAsync,
    required this.routeInfo,
    required this.tripOrigin,
    required this.tripDestination,
    required this.stops,
    required this.loadingLabel,
    required this.onMapTap,
  });

  static const _epnLocation = LatLng(-0.2106, -78.4889);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MARCAR TU PARADA', style: AppTextStyles.labelSmall),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 320,
              child: locationAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _MapView(
                  center: tripOrigin ?? _epnLocation,
                  routeInfo: routeInfo,
                  tripOrigin: tripOrigin,
                  tripDestination: tripDestination,
                  stops: stops,
                  onMapTap: onMapTap,
                ),
                data: (location) => _MapView(
                  center:
                      (stops.isNotEmpty
                          ? LatLng(stops.last.latitude, stops.last.longitude)
                          : null) ??
                      tripOrigin ??
                      LatLng(location.latitude, location.longitude),
                  routeInfo: routeInfo,
                  tripOrigin: tripOrigin,
                  tripDestination: tripDestination,
                  stops: stops,
                  onMapTap: onMapTap,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            loadingLabel
                ? 'Buscando dirección...'
                : 'Toca la ruta para elegir tu única parada.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  final LatLng center;
  final RouteInfo? routeInfo;
  final LatLng? tripOrigin;
  final LatLng? tripDestination;
  final List<TripRequestStop> stops;
  final ValueChanged<LatLng> onMapTap;

  const _MapView({
    required this.center,
    required this.routeInfo,
    required this.tripOrigin,
    required this.tripDestination,
    required this.stops,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        onTap: (_, point) => onMapTap(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nexuscampus.app',
        ),
        if (routeInfo != null && routeInfo!.points.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routeInfo!.points,
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (tripOrigin != null)
              Marker(
                point: tripOrigin!,
                width: 42,
                height: 42,
                child: const _MapMarker(
                  icon: Icons.trip_origin,
                  color: AppColors.primary,
                ),
              ),
            if (tripDestination != null)
              Marker(
                point: tripDestination!,
                width: 42,
                height: 42,
                child: const _MapMarker(
                  icon: Icons.flag,
                  color: AppColors.primaryMid,
                ),
              ),
            for (var i = 0; i < stops.length; i++)
              Marker(
                point: LatLng(stops[i].latitude, stops[i].longitude),
                width: 46,
                height: 46,
                child: _NumberedMapMarker(index: i + 1),
              ),
          ],
        ),
      ],
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
            color: Color.fromRGBO(13, 111, 148, 0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _NumberedMapMarker extends StatelessWidget {
  final int index;

  const _NumberedMapMarker({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(13, 111, 148, 0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$index',
          style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
