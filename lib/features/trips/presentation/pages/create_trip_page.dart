import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/map_tiles.dart';
import '../../../../core/constants/app_limits.dart';
import '../../../../core/constants/app_text_styles.dart';

import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/utils/geo_fare.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../map/domain/entities/route_info.dart';
import '../../../map/domain/entities/user_location.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../vehicles/presentation/providers/vehicle_provider.dart';
import '../providers/trip_provider.dart';

/// Page for creating or editing a trip with Coastal Wave form design.
class CreateTripPage extends ConsumerStatefulWidget {
  final String? editTripId;

  const CreateTripPage({this.editTripId, super.key});

  @override
  ConsumerState<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends ConsumerState<CreateTripPage> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _commentController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _seats = 3;
  bool _selectingOrigin = true;
  bool _isLoadingRoute = false;
  bool _isLoadingEdit = false;
  LatLng? _originPoint;
  LatLng? _destinationPoint;
  RouteInfo? _routeInfo;
  String? _routeError;
  Timer? _destinationDebounce;
  List<PlaceSuggestion> _destinationSuggestions = const [];
  bool _isSearchingDestination = false;
  int _destinationSearchGeneration = 0;

  bool get _isEditing => widget.editTripId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadTripForEdit();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _useCurrentLocation();
      });
    }
  }

  Future<void> _useCurrentLocation({bool refresh = false}) async {
    if (refresh) {
      ref.invalidate(currentLocationProvider);
    }
    try {
      final location = await ref.read(currentLocationProvider.future);
      if (!mounted) return;
      final point = LatLng(location.latitude, location.longitude);
      setState(() {
        _originPoint = point;
        _originController.text = 'Buscando dirección...';
        _selectingOrigin = false;
        _routeInfo = null;
        _routeError = null;
        _priceController.clear();
      });
      await _loadPointLabel(point, selectingOrigin: true);
      if (_destinationPoint != null) await _loadRoute();
    } catch (e) {
      if (!mounted || !refresh) return;
      showAppSnackBar(
        context,
        title: 'Ubicación no actualizada',
        message: 'No pudimos obtener tu ubicación actual. $e',
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _loadTripForEdit() async {
    final tripId = widget.editTripId;
    if (tripId == null) return;
    setState(() => _isLoadingEdit = true);
    try {
      final trip = await ref.read(tripByIdProvider(tripId).future);
      if (!mounted) return;
      setState(() {
        _originController.text = trip.origin;
        _destinationController.text = trip.destination;
        _priceController.text = trip.pricePerSeat.toStringAsFixed(2);
        _seats = trip.totalSeats.clamp(1, AppLimits.maxTripSeats).toInt();
        _selectedDate = DateTime(
          trip.departureTime.year,
          trip.departureTime.month,
          trip.departureTime.day,
        );
        _selectedTime = TimeOfDay(
          hour: trip.departureTime.hour,
          minute: trip.departureTime.minute,
        );
        if (trip.originLatitude != null && trip.originLongitude != null) {
          _originPoint = LatLng(trip.originLatitude!, trip.originLongitude!);
        }
        if (trip.destinationLatitude != null &&
            trip.destinationLongitude != null) {
          _destinationPoint = LatLng(
            trip.destinationLatitude!,
            trip.destinationLongitude!,
          );
        }
        if (trip.routeDistanceMeters != null ||
            trip.routeDurationSeconds != null ||
            trip.routePoints?.isNotEmpty == true) {
          _routeInfo = RouteInfo(
            points: trip.routePoints?.isNotEmpty == true
                ? trip.routePoints!
                : [?_originPoint, ?_destinationPoint],
            distanceMeters: trip.routeDistanceMeters ?? 0,
            durationSeconds: trip.routeDurationSeconds ?? 0,
          );
        }
      });
      if (_originPoint != null && _destinationPoint != null) {
        await _loadRoute();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          title: 'No se pudo cargar el viaje',
          message: e.toString(),
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingEdit = false);
    }
  }

  @override
  void dispose() {
    _destinationDebounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _commentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onDestinationChanged(String value) {
    _destinationDebounce?.cancel();
    final generation = ++_destinationSearchGeneration;
    setState(() {
      _destinationPoint = null;
      _destinationSuggestions = const [];
      _isSearchingDestination = false;
      _routeInfo = null;
      _routeError = null;
      _priceController.clear();
    });
    if (value.trim().length < 3) return;

    _destinationDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || generation != _destinationSearchGeneration) return;
      setState(() => _isSearchingDestination = true);
      try {
        final results = await GeocodingService.search(value);
        if (!mounted || generation != _destinationSearchGeneration) return;
        setState(() => _destinationSuggestions = results);
      } catch (_) {
        if (mounted && generation == _destinationSearchGeneration) {
          setState(() => _destinationSuggestions = const []);
        }
      } finally {
        if (mounted && generation == _destinationSearchGeneration) {
          setState(() => _isSearchingDestination = false);
        }
      }
    });
  }

  Future<void> _selectDestination(PlaceSuggestion suggestion) async {
    _destinationDebounce?.cancel();
    _destinationSearchGeneration++;
    setState(() {
      _destinationController.text = suggestion.displayName;
      _destinationPoint = suggestion.point;
      _destinationSuggestions = const [];
      _isSearchingDestination = false;
      _selectingOrigin = false;
      _routeInfo = null;
      _routeError = null;
      _priceController.clear();
    });
    if (_originPoint != null) await _loadRoute();
  }

  void _updateFare() {
    final route = _routeInfo;
    if (route == null || route.distanceMeters <= 0) {
      _priceController.clear();
      return;
    }
    final price = TripFareCalculator.pricePerSeat(
      distanceMeters: route.distanceMeters,
      seats: _seats,
    );
    _priceController.text = price.toStringAsFixed(2);
  }

  String? get _fareHint {
    final route = _routeInfo;
    if (route == null || route.distanceMeters <= 0) return null;
    final total = TripFareCalculator.totalFareFromMeters(route.distanceMeters);
    final perSeat = TripFareCalculator.pricePerSeat(
      distanceMeters: route.distanceMeters,
      seats: _seats,
    );
    return 'Tarifa estimada: \$${total.toStringAsFixed(2)} · '
        '\$${perSeat.toStringAsFixed(2)} por asiento';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
    );
    if (time != null && mounted) {
      setState(() => _selectedTime = time);
    }
  }

  DateTime? _buildDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  String? _formattedSelectedDate() {
    final date = _selectedDate;
    if (date == null) {
      return null;
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String? _formattedSelectedTime(BuildContext context) {
    final time = _selectedTime;
    if (time == null) {
      return null;
    }
    return time.format(context);
  }

  Future<void> _setRoutePoint(LatLng point) async {
    final selectingOrigin = _selectingOrigin;
    final loadingLabel = 'Buscando dirección...';
    setState(() {
      if (selectingOrigin) {
        _originPoint = point;
        _originController.text = loadingLabel;
        _selectingOrigin = false;
      } else {
        _destinationPoint = point;
        _destinationController.text = loadingLabel;
      }
      _routeInfo = null;
      _routeError = null;
      _priceController.clear();
    });

    await _loadPointLabel(point, selectingOrigin: selectingOrigin);

    if (_originPoint != null && _destinationPoint != null) {
      await _loadRoute();
    }
  }

  Future<void> _loadPointLabel(
    LatLng point, {
    required bool selectingOrigin,
  }) async {
    final fallbackLabel = _fallbackPointLabel(point);
    try {
      final label = await ref.read(reverseGeocodeProvider(point).future);
      if (!mounted) return;
      setState(() {
        if (selectingOrigin && _originPoint == point) {
          _originController.text = label;
        } else if (!selectingOrigin && _destinationPoint == point) {
          _destinationController.text = label;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (selectingOrigin && _originPoint == point) {
          _originController.text = fallbackLabel;
        } else if (!selectingOrigin && _destinationPoint == point) {
          _destinationController.text = fallbackLabel;
        }
      });
    }
  }

  String _fallbackPointLabel(LatLng point) {
    return 'Punto marcado (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
  }

  Future<void> _loadRoute() async {
    final origin = _originPoint;
    final destination = _destinationPoint;
    if (origin == null || destination == null) return;

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    try {
      final route = await ref.read(
        routeInfoProvider(
          RouteRequest(origin: origin, destination: destination),
        ).future,
      );
      if (!mounted) return;
      setState(() => _routeInfo = route);
      _updateFare();
    } catch (e) {
      if (!mounted) return;
      // Fallback on slow/blocked mobile data: straight line so publishing
      // still works when OSRM is unreachable.
      final distance = const Distance().as(
        LengthUnit.Meter,
        origin,
        destination,
      );
      final fallback = RouteInfo(
        points: [origin, destination],
        distanceMeters: distance,
        durationSeconds: distance / 8.3, // ~30 km/h urban estimate
      );
      setState(() {
        _routeInfo = fallback;
        _routeError =
            'Ruta aproximada (sin servicio de navegación). Puedes publicar igual.';
      });
      _updateFare();
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final notifierState = ref.watch(tripNotifierProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    ref.listen(tripNotifierProvider, (previous, next) {
      if (next is AsyncError && mounted) {
        showAppSnackBar(
          context,
          title: _isEditing
              ? 'No se guardaron los cambios'
              : 'No se publicó el viaje',
          message: next.error.toString(),
          type: AppSnackBarType.error,
        );
      } else if (next is AsyncData && previous is AsyncLoading && mounted) {
        showAppSnackBar(
          context,
          title: _isEditing ? 'Viaje actualizado' : 'Viaje publicado',
          message: _isEditing
              ? 'Los cambios quedaron guardados correctamente.'
              : 'Tu viaje ya está disponible para recibir solicitudes.',
          type: AppSnackBarType.success,
        );
        context.pop();
      }
    });

    if (_isLoadingEdit) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar viaje' : 'Publicar viaje'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditing ? 'Editar viaje' : 'Publicar viaje'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeCard(),
              const SizedBox(height: 16),
              _FormCard(
                icon: Icons.location_on,
                label: 'ORIGEN',
                hint: '¿Desde dónde sales?',
                controller: _originController,
              ),
              const SizedBox(height: 12),
              _FormCard(
                icon: Icons.explore,
                label: 'DESTINO',
                hint: '¿Hacia dónde vas?',
                controller: _destinationController,
                onChanged: _onDestinationChanged,
                suggestions: _destinationSuggestions,
                isSearching: _isSearchingDestination,
                onSuggestionSelected: _selectDestination,
              ),
              const SizedBox(height: 12),
              _RoutePickerCard(
                locationAsync: locationAsync,
                originPoint: _originPoint,
                destinationPoint: _destinationPoint,
                routeInfo: _routeInfo,
                routeError: _routeError,
                isLoadingRoute: _isLoadingRoute,
                selectingOrigin: _selectingOrigin,
                onSelectingOriginChanged: (value) {
                  setState(() => _selectingOrigin = value);
                },
                onMapTap: _setRoutePoint,
                onRefreshLocation: () => _useCurrentLocation(refresh: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateCard(
                      icon: Icons.calendar_today,
                      label: 'FECHA',
                      value: _formattedSelectedDate(),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateCard(
                      icon: Icons.schedule,
                      label: 'HORA',
                      value: _formattedSelectedTime(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FormCard(
                icon: Icons.payments,
                label: 'PRECIO POR ASIENTO',
                hint: '0.00',
                controller: _priceController,
                prefix: '\$',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                readOnly: true,
                helperText: _fareHint,
              ),
              const SizedBox(height: 12),
              _SeatsStepper(
                seats: _seats,
                onChanged: (v) {
                  setState(() => _seats = v);
                  _updateFare();
                },
              ),
              const SizedBox(height: 12),
              _CommentCard(controller: _commentController),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
            label: _isEditing ? 'Guardar cambios' : 'Publicar viaje',
            isLoading: notifierState.isLoading,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final dt = _buildDateTime();
              if (dt == null) {
                showAppSnackBar(
                  context,
                  title: 'Falta fecha y hora',
                  message: 'Selecciona cuándo saldrá el viaje.',
                  type: AppSnackBarType.warning,
                );
                return;
              }
              if (userId == null) return;
              if (_seats > AppLimits.maxTripSeats) {
                showAppSnackBar(
                  context,
                  title: 'Cupos fuera del límite',
                  message: 'Puedes publicar máximo 4 asientos por viaje.',
                  type: AppSnackBarType.warning,
                );
                return;
              }
              if (!_isEditing) {
                final vehicle = await ref.read(
                  myVehicleProvider(userId).future,
                );
                if (!context.mounted) return;
                if (vehicle?.isApproved != true) {
                  showAppSnackBar(
                    context,
                    title: 'Vehículo pendiente',
                    message:
                        'Tu vehículo debe estar aprobado antes de publicar un viaje.',
                    type: AppSnackBarType.warning,
                  );
                  return;
                }
              }
              if (!context.mounted) return;
              if (_originPoint == null || _destinationPoint == null) {
                showAppSnackBar(
                  context,
                  title: 'Ruta incompleta',
                  message: 'Marca el origen y el destino en el mapa.',
                  type: AppSnackBarType.warning,
                );
                return;
              }
              if (_routeInfo == null || _routeInfo!.points.isEmpty) {
                showAppSnackBar(
                  context,
                  title: 'Ruta no calculada',
                  message:
                      'Calcula una ruta válida antes de publicar el viaje.',
                  type: AppSnackBarType.warning,
                );
                return;
              }
              if (_isEditing) {
                final tripId = widget.editTripId!;
                final existing = await ref.read(
                  tripByIdProvider(tripId).future,
                );
                final occupiedSeats =
                    existing.totalSeats - existing.availableSeats;
                final availableSeats = (_seats - occupiedSeats).clamp(
                  0,
                  _seats,
                );
                await ref
                    .read(tripNotifierProvider.notifier)
                    .updateTrip(tripId, userId, {
                      'origin': _originController.text.trim(),
                      'destination': _destinationController.text.trim(),
                      'departure_time': dt.toIso8601String(),
                      'total_seats': _seats,
                      'available_seats': availableSeats,
                      'price_per_seat': double.parse(
                        _priceController.text.trim(),
                      ),
                      'origin_latitude': _originPoint!.latitude,
                      'origin_longitude': _originPoint!.longitude,
                      'destination_latitude': _destinationPoint!.latitude,
                      'destination_longitude': _destinationPoint!.longitude,
                      'route_distance_meters': _routeInfo?.distanceMeters,
                      'route_duration_seconds': _routeInfo?.durationSeconds,
                      'route_points': RouteGeometry.encodePoints(
                        _routeInfo!.points,
                      ),
                    });
              } else {
                await ref
                    .read(tripNotifierProvider.notifier)
                    .createTrip(
                      userId,
                      _originController.text.trim(),
                      _destinationController.text.trim(),
                      dt,
                      _seats,
                      double.parse(_priceController.text.trim()),
                      originLatitude: _originPoint!.latitude,
                      originLongitude: _originPoint!.longitude,
                      destinationLatitude: _destinationPoint!.latitude,
                      destinationLongitude: _destinationPoint!.longitude,
                      routeDistanceMeters: _routeInfo?.distanceMeters,
                      routeDurationSeconds: _routeInfo?.durationSeconds,
                      routePoints: RouteGeometry.encodePoints(
                        _routeInfo!.points,
                      ),
                    );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _RoutePickerCard extends StatelessWidget {
  final AsyncValue<UserLocation> locationAsync;
  final LatLng? originPoint;
  final LatLng? destinationPoint;
  final RouteInfo? routeInfo;
  final String? routeError;
  final bool isLoadingRoute;
  final bool selectingOrigin;
  final ValueChanged<bool> onSelectingOriginChanged;
  final ValueChanged<LatLng> onMapTap;
  final VoidCallback onRefreshLocation;

  const _RoutePickerCard({
    required this.locationAsync,
    required this.originPoint,
    required this.destinationPoint,
    required this.routeInfo,
    required this.routeError,
    required this.isLoadingRoute,
    required this.selectingOrigin,
    required this.onSelectingOriginChanged,
    required this.onMapTap,
    required this.onRefreshLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'MAPA DE RUTA',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RouteModeButton(
                  label: 'Origen',
                  icon: Icons.trip_origin,
                  isSelected: selectingOrigin,
                  onTap: () => onSelectingOriginChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RouteModeButton(
                  label: 'Destino',
                  icon: Icons.flag,
                  isSelected: !selectingOrigin,
                  onTap: () => onSelectingOriginChanged(false),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRefreshLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Actualizar GPS'),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 260,
              child: locationAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Ubicación no disponible: $e')),
                data: (location) {
                  final center =
                      originPoint ??
                      LatLng(location.latitude, location.longitude);
                  final markers = <Marker>[
                    if (originPoint != null)
                      Marker(
                        point: originPoint!,
                        width: 48,
                        height: 48,
                        child: _MapMarker(
                          icon: Icons.trip_origin,
                          color: AppColors.primary,
                        ),
                      ),
                    if (destinationPoint != null)
                      Marker(
                        point: destinationPoint!,
                        width: 48,
                        height: 48,
                        child: _MapMarker(
                          icon: Icons.flag,
                          color: AppColors.primaryMid,
                        ),
                      ),
                  ];

                  return FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14,
                      onTap: (_, point) => onMapTap(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: MapTiles.urlTemplate,
                    subdomains: MapTiles.subdomains,
                    userAgentPackageName: MapTiles.userAgentPackageName,
                      ),
                      if (routeInfo != null && routeInfo!.points.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routeInfo!.points,
                              color: AppColors.primary,
                              strokeWidth: 5,
                            ),
                          ],
                        ),
                      MarkerLayer(markers: markers),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isLoadingRoute)
            const LinearProgressIndicator(minHeight: 2)
          else if (routeInfo != null)
            Row(
              children: [
                Icon(Icons.route, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${(routeInfo!.distanceMeters / 1000).toStringAsFixed(1)} km',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${(routeInfo!.durationSeconds / 60).round()} min',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            )
          else
            Text(
              routeError ?? 'Toca el mapa para marcar origen y destino.',
              style: AppTextStyles.bodySmall.copyWith(
                color: routeError == null
                    ? AppColors.textSecondary
                    : AppColors.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? AppColors.onPrimary : AppColors.primary,
        backgroundColor: isSelected ? AppColors.primary : Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.outlineVariant,
        ),
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

class _WelcomeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'Comparte tu ruta',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Reduce costos y conoce gente nueva.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? prefix;
  final TextInputType? keyboardType;
  final bool readOnly;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final List<PlaceSuggestion> suggestions;
  final bool isSearching;
  final ValueChanged<PlaceSuggestion>? onSuggestionSelected;

  const _FormCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.prefix,
    this.keyboardType,
    this.readOnly = false,
    this.helperText,
    this.onChanged,
    this.suggestions = const [],
    this.isSearching = false,
    this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.labelSmall.copyWith(
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (prefix != null)
                      Row(
                        children: [
                          Text(
                            prefix!,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.onBackground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              keyboardType: keyboardType,
                              readOnly: readOnly,
                              onChanged: onChanged,
                              decoration: InputDecoration.collapsed(
                                hintText: hint,
                                hintStyle: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.outline,
                                ),
                              ),
                              style: AppTextStyles.bodyLarge,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Campo requerido';
                                }
                                final n = double.tryParse(v.trim());
                                if (n == null || n <= 0) {
                                  return 'Debe ser mayor a 0';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      TextFormField(
                        controller: controller,
                        readOnly: readOnly,
                        onChanged: onChanged,
                        decoration: InputDecoration.collapsed(
                          hintText: hint,
                          hintStyle: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        style: AppTextStyles.bodyLarge,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 10),
            Text(
              helperText!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (isSearching) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...suggestions.map(
              (suggestion) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  suggestion.displayName,
                  style: AppTextStyles.bodySmall,
                ),
                onTap: () => onSuggestionSelected?.call(suggestion),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(13, 111, 148, 0.08),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? 'Seleccionar',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: value != null
                          ? AppColors.onBackground
                          : AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatsStepper extends StatelessWidget {
  final int seats;
  final ValueChanged<int> onChanged;

  const _SeatsStepper({required this.seats, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          Text(
            'ASIENTOS DISPONIBLES',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: seats > 1 ? () => onChanged(seats - 1) : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: seats > 1
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '$seats',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: seats < AppLimits.maxTripSeats
                    ? () => onChanged(seats + 1)
                    : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: seats < AppLimits.maxTripSeats
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final TextEditingController controller;

  const _CommentCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'COMENTARIOS ADICIONALES',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration.collapsed(
              hintText: 'Ej: No se permite fumar, espacio para maletas...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.outline,
              ),
            ),
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
