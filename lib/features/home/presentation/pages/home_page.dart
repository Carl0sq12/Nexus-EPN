import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../ratings/presentation/widgets/rating_dialog.dart';
import '../../../requests/domain/entities/trip_request.dart';
import '../../../requests/presentation/providers/request_provider.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_provider.dart';

/// Main home page with a stable dashboard, map preview, and request status.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  bool _locationPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _locationPromptShown = false;
    ref.invalidate(currentLocationProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;
    final locationAsync = ref.watch(currentLocationProvider);
    final tripsAsync = ref.watch(availableTripsProvider);
    final profileAsync = userId == null
        ? null
        : ref.watch(profileProvider(userId));
    final isDriver =
        profileAsync?.maybeWhen(
          data: (profile) => profile.role == AppStrings.roleDriver,
          orElse: () => false,
        ) ??
        false;
    final requestsAsync = userId == null
        ? null
        : ref.watch(myRequestsProvider(userId));
    final pendingRatingsAsync = !isDriver && userId != null
        ? ref.watch(pendingDriverRatingsProvider(userId))
        : null;
    final myTripsAsync = isDriver && userId != null
        ? ref.watch(myTripsProvider(userId))
        : null;

    ref.listen(currentLocationProvider, (previous, next) {
      if (next.hasValue) {
        _locationPromptShown = false;
        return;
      }
      if (!next.hasError || _locationPromptShown) return;
      _locationPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLocationPrompt(next.error.toString());
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentLocationProvider);
          ref.invalidate(availableTripsProvider);
          if (userId != null) {
            ref.invalidate(myRequestsProvider(userId));
            ref.invalidate(profileProvider(userId));
            if (isDriver) ref.invalidate(myTripsProvider(userId));
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _HomeHeader(isDriver: isDriver)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.list(
                children: [
                  _DashboardSection(
                    tripsAsync: tripsAsync,
                    requestsAsync: requestsAsync,
                    myTripsAsync: myTripsAsync,
                    isDriver: isDriver,
                  ),
                  const SizedBox(height: 16),
                  _MapSection(
                    locationAsync: locationAsync,
                    onRetryLocation: () {
                      _locationPromptShown = false;
                      ref.invalidate(currentLocationProvider);
                    },
                  ),
                  const SizedBox(height: 16),
                  _QuickActions(isDriver: isDriver),
                  const SizedBox(height: 16),
                  if (!isDriver && requestsAsync != null) ...[
                    _PassengerRequestsSection(requestsAsync: requestsAsync),
                    const SizedBox(height: 16),
                  ],
                  if (!isDriver &&
                      userId != null &&
                      pendingRatingsAsync != null) ...[
                    _PendingDriverRatingsSection(
                      passengerId: userId,
                      pendingRatingsAsync: pendingRatingsAsync,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _AvailableTripsSection(tripsAsync: tripsAsync),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationPrompt(String error) async {
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
        ? 'Para mostrar tu posición en el mapa necesitas activar la ubicación del dispositivo.'
        : permanentlyDenied
        ? 'La app no tiene permiso de ubicación. Actívalo desde los ajustes del sistema.'
        : 'Para mostrar tu posición en el mapa necesitamos permiso de ubicación.';
    final actionLabel = serviceDisabled || permanentlyDenied
        ? 'Abrir ajustes'
        : 'Permitir';

    final accepted = await showDialog<bool>(
      context: context,
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
    ref.invalidate(currentLocationProvider);
  }
}

class _HomeHeader extends StatelessWidget {
  final bool isDriver;

  const _HomeHeader({required this.isDriver});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        18,
      ),
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.appName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDriver ? 'Panel de conductor' : 'Panel de pasajero',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notificaciones',
                icon: const Icon(Icons.notifications_outlined),
                color: Colors.white,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(AppStrings.routeTrips),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isDriver
                            ? 'Revisa tus viajes o publica una ruta'
                            : AppStrings.searchHint,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 20,
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

class _DashboardSection extends StatelessWidget {
  final AsyncValue<List<Trip>> tripsAsync;
  final AsyncValue<List<TripRequest>>? requestsAsync;
  final AsyncValue<List<Trip>>? myTripsAsync;
  final bool isDriver;

  const _DashboardSection({
    required this.tripsAsync,
    required this.requestsAsync,
    required this.myTripsAsync,
    required this.isDriver,
  });

  @override
  Widget build(BuildContext context) {
    final availableTrips = tripsAsync.maybeWhen(
      data: (trips) => trips.length.toString(),
      loading: () => '...',
      orElse: () => '-',
    );
    final primaryLabel = isDriver ? 'Mis viajes' : 'Solicitudes';
    final primaryValue = isDriver
        ? myTripsAsync?.maybeWhen(
                data: (trips) => trips.length.toString(),
                loading: () => '...',
                orElse: () => '-',
              ) ??
              '-'
        : requestsAsync?.maybeWhen(
                data: (requests) => requests.length.toString(),
                loading: () => '...',
                orElse: () => '-',
              ) ??
              '-';
    final secondaryLabel = isDriver ? 'Rutas llenas' : 'Aceptadas';
    final secondaryValue = isDriver
        ? myTripsAsync?.maybeWhen(
                data: (trips) => trips
                    .where(
                      (trip) =>
                          trip.status == AppStrings.statusFull ||
                          trip.availableSeats == 0,
                    )
                    .length
                    .toString(),
                loading: () => '...',
                orElse: () => '-',
              ) ??
              '-'
        : requestsAsync?.maybeWhen(
                data: (requests) => requests
                    .where(
                      (request) => request.status == AppStrings.statusAccepted,
                    )
                    .length
                    .toString(),
                loading: () => '...',
                orElse: () => '-',
              ) ??
              '-';

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.directions_car_outlined,
            label: 'Disponibles',
            value: availableTrips,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: isDriver ? Icons.assignment_outlined : Icons.send_outlined,
            label: primaryLabel,
            value: primaryValue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            icon: isDriver ? Icons.route_outlined : Icons.check_circle_outline,
            label: secondaryLabel,
            value: secondaryValue,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
          Icon(icon, color: AppColors.primary, size: 20),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onBackground,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  final AsyncValue<dynamic> locationAsync;
  final VoidCallback onRetryLocation;

  const _MapSection({
    required this.locationAsync,
    required this.onRetryLocation,
  });

  static const _epnLocation = LatLng(-0.2106, -78.4889);

  @override
  Widget build(BuildContext context) {
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('Mapa cercano', style: AppTextStyles.titleMedium),
                ),
                Text(
                  'Ubicación actual',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 260,
            child: locationAsync.when(
              loading: () => const _MapPlaceholder(
                icon: Icons.my_location,
                label: AppStrings.loadingLocation,
              ),
              error: (_, _) => _MapPreview(
                center: _epnLocation,
                icon: Icons.school_outlined,
                label: 'EPN',
                helperText:
                    'Activa la ubicación para ver tu posición actual. Toca para reintentar.',
                onTap: onRetryLocation,
              ),
              data: (location) {
                final center = LatLng(location.latitude, location.longitude);
                return _MapPreview(
                  center: center,
                  icon: Icons.person_pin_circle,
                  label: 'Tu ubicación',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final LatLng center;
  final IconData icon;
  final String label;
  final String? helperText;
  final VoidCallback? onTap;

  const _MapPreview({
    required this.center,
    required this.icon,
    required this.label,
    this.helperText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nexuscampus.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  helperText ?? label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MapPlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primarySoft,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isDriver;

  const _QuickActions({required this.isDriver});

  @override
  Widget build(BuildContext context) {
    final actions = isDriver
        ? [
            _ActionItem(
              icon: Icons.add_road_outlined,
              label: 'Publicar',
              onTap: () => context.push(AppStrings.routeTripsNew),
            ),
            _ActionItem(
              icon: Icons.assignment_outlined,
              label: 'Mis viajes',
              onTap: () => context.push(AppStrings.routeMyTrips),
            ),
            _ActionItem(
              icon: Icons.map_outlined,
              label: 'Mapa',
              onTap: () => context.push(AppStrings.routeMap),
            ),
          ]
        : [
            _ActionItem(
              icon: Icons.search,
              label: 'Buscar',
              onTap: () => context.push(AppStrings.routeTrips),
            ),
            _ActionItem(
              icon: Icons.send_outlined,
              label: 'Solicitudes',
              onTap: () => context.push(AppStrings.routeTrips),
            ),
            _ActionItem(
              icon: Icons.map_outlined,
              label: 'Mapa',
              onTap: () => context.push(AppStrings.routeMap),
            ),
          ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(child: actions[i]),
          if (i < actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengerRequestsSection extends StatelessWidget {
  final AsyncValue<List<TripRequest>> requestsAsync;

  const _PassengerRequestsSection({required this.requestsAsync});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Mis solicitudes',
      trailing: TextButton(
        onPressed: () => context.push(AppStrings.routeTrips),
        child: const Text('Buscar viajes'),
      ),
      child: requestsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No se pudieron cargar tus solicitudes. Desliza para actualizar.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return Text(
              'Cuando solicites un cupo, aparecerá aquí el estado para comprobar si fue enviada, aceptada o rechazada.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            );
          }

          final recent = [...requests]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return Column(
            children: recent
                .take(3)
                .map((request) => _RequestStatusRow(request: request))
                .toList(),
          );
        },
      ),
    );
  }
}

class _PendingDriverRatingsSection extends ConsumerWidget {
  final String passengerId;
  final AsyncValue<List<PendingDriverRating>> pendingRatingsAsync;

  const _PendingDriverRatingsSection({
    required this.passengerId,
    required this.pendingRatingsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return pendingRatingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => _SectionContainer(
        title: 'Calificaciones pendientes',
        child: Text(e.toString(), style: AppTextStyles.bodySmall),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return _SectionContainer(
          title: 'Califica al conductor',
          child: Column(
            children: items
                .map(
                  (item) => _PendingDriverRatingRow(
                    passengerId: passengerId,
                    item: item,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _PendingDriverRatingRow extends ConsumerWidget {
  final String passengerId;
  final PendingDriverRating item;

  const _PendingDriverRatingRow({
    required this.passengerId,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingState = ref.watch(ratingNotifierProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Viaje finalizado',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.origin} → ${item.destination}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ratingState.isLoading
                  ? null
                  : () => _rateDriver(context, ref),
              icon: const Icon(Icons.star_outline),
              label: const Text('Calificar conductor'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rateDriver(BuildContext context, WidgetRef ref) async {
    final result = await RatingDialog.show(context);
    if (result == null) return;

    await ref
        .read(ratingNotifierProvider.notifier)
        .sendRating(
          tripId: item.tripId,
          raterId: passengerId,
          ratedUserId: item.driverId,
          score: result.score,
          comment: result.comment,
        );

    ref.invalidate(pendingDriverRatingsProvider(passengerId));
    ref.invalidate(ratingsForUserProvider(item.driverId));
    if (!context.mounted) return;

    final nextState = ref.read(ratingNotifierProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextState.hasError
              ? nextState.error.toString()
              : 'Calificación enviada',
        ),
      ),
    );
  }
}

class _RequestStatusRow extends StatelessWidget {
  final TripRequest request;

  const _RequestStatusRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = _statusText(request.status);
    final color = _statusColor(request.status);
    final date = DateFormat('dd/MM HH:mm').format(request.createdAt);
    final shortTripId = request.tripId.substring(
      0,
      request.tripId.length < 8 ? request.tripId.length : 8,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(request.status), color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Viaje $shortTripId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(label: status, color: color),
        ],
      ),
    );
  }

  String _statusText(String status) {
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

  IconData _statusIcon(String status) {
    switch (status) {
      case AppStrings.statusAccepted:
        return Icons.check;
      case AppStrings.statusPriceProposed:
        return Icons.payments_outlined;
      case AppStrings.statusRejected:
        return Icons.close;
      default:
        return Icons.schedule;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppStrings.statusAccepted:
        return AppColors.success;
      case AppStrings.statusPriceProposed:
        return AppColors.primary;
      case AppStrings.statusRejected:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }
}

class _AvailableTripsSection extends StatelessWidget {
  final AsyncValue<List<Trip>> tripsAsync;

  const _AvailableTripsSection({required this.tripsAsync});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Viajes disponibles',
      trailing: TextButton(
        onPressed: () => context.push(AppStrings.routeTrips),
        child: const Text('Ver todos'),
      ),
      child: tripsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(e.toString(), style: AppTextStyles.bodySmall),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return Text(
              'No hay viajes disponibles por ahora.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            );
          }

          return Column(
            children: trips
                .take(4)
                .map((trip) => _TripPreviewCard(trip: trip))
                .toList(),
          );
        },
      ),
    );
  }
}

class _TripPreviewCard extends StatelessWidget {
  final Trip trip;

  const _TripPreviewCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(trip.departureTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/trips/${trip.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.route, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.origin} → ${trip.destination}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$time · ${trip.availableSeats} cupos · \$${trip.pricePerSeat.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionContainer({
    required this.title,
    required this.child,
    this.trailing,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
