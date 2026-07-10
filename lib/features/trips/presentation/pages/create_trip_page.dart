import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../map/domain/entities/route_info.dart';
import '../../../map/domain/entities/user_location.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../providers/trip_provider.dart';

/// Page for creating a new trip with Coastal Wave form design.
class CreateTripPage extends ConsumerStatefulWidget {
  const CreateTripPage({super.key});

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
  LatLng? _originPoint;
  LatLng? _destinationPoint;
  RouteInfo? _routeInfo;
  String? _routeError;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _commentController.dispose();
    _priceController.dispose();
    super.dispose();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _routeError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;
    final notifierState = ref.watch(tripNotifierProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    ref.listen(tripNotifierProvider, (previous, next) {
      if (next is AsyncError && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      } else if (next is AsyncData && mounted) {
        context.pop();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Publicar viaje'),
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
              ),
              const SizedBox(height: 12),
              _SeatsStepper(
                seats: _seats,
                onChanged: (v) => setState(() => _seats = v),
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
            label: 'Publicar viaje',
            isLoading: notifierState.isLoading,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final dt = _buildDateTime();
              if (dt == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selecciona fecha y hora')),
                );
                return;
              }
              if (userId == null) return;
              if (_originPoint == null || _destinationPoint == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Marca origen y destino en el mapa'),
                  ),
                );
                return;
              }
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
                  );
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
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nexuscampus.app',
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

  const _FormCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.prefix,
    this.keyboardType,
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1),
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
                onTap: seats < 8 ? () => onChanged(seats + 1) : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: seats < 8
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
