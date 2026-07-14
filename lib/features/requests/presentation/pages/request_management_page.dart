import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/map_tiles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/trip_request.dart';
import '../providers/request_provider.dart';
import '../../../trips/presentation/providers/trip_provider.dart';

/// Page where the driver can view and manage incoming requests for a trip.
class RequestManagementPage extends ConsumerWidget {
  final String tripId;

  const RequestManagementPage({required this.tripId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(requestsByTripProvider(tripId));
    final requestState = ref.watch(requestNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.requestsTitle),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: requestsAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, _) => AppErrorView(
          message:
              'No pudimos cargar las solicitudes de este viaje. Revisa tu conexión e inténtalo de nuevo.',
          onRetry: () => ref.invalidate(requestsByTripProvider(tripId)),
        ),
        data: (requests) {
          final pending = requests
              .where((request) => request.status == AppStrings.statusPending)
              .toList();
          final proposed = requests
              .where(
                (request) => request.status == AppStrings.statusPriceProposed,
              )
              .toList();
          final accepted = requests
              .where((request) => request.status == AppStrings.statusAccepted)
              .toList();
          final rejected = requests
              .where((request) => request.status == AppStrings.statusRejected)
              .toList();

          if (requests.isEmpty) {
            return const Center(child: Text(AppStrings.noRequests));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(requestsByTripProvider(tripId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _RequestSummary(
                  pending: pending.length,
                  proposed: proposed.length,
                  accepted: accepted.length,
                  rejected: rejected.length,
                ),
                const SizedBox(height: 16),
                _RequestSection(
                  title: 'Pendientes',
                  emptyText: AppStrings.noPendingRequests,
                  requests: pending,
                  color: AppColors.warning,
                  isBusy: requestState.isLoading,
                  onAccept: (request) async {
                    await ref
                        .read(requestNotifierProvider.notifier)
                        .acceptRequest(request.id, tripId);
                    if (!context.mounted) return;
                    final nextState = ref.read(requestNotifierProvider);
                    showAppSnackBar(
                      context,
                      title: nextState.hasError
                          ? 'No se aceptó la solicitud'
                          : 'Solicitud aceptada',
                      message: nextState.hasError
                          ? nextState.error.toString()
                          : 'El pasajero fue agregado al viaje y recibió la confirmación.',
                      type: nextState.hasError
                          ? AppSnackBarType.error
                          : AppSnackBarType.success,
                    );
                  },
                  onReject: (request) async {
                    await ref
                        .read(requestNotifierProvider.notifier)
                        .rejectRequest(
                          request.id,
                          tripId: tripId,
                          passengerId: request.passengerId,
                        );
                    if (!context.mounted) return;
                    final nextState = ref.read(requestNotifierProvider);
                    showAppSnackBar(
                      context,
                      title: nextState.hasError
                          ? 'No se rechazó la solicitud'
                          : 'Solicitud rechazada',
                      message: nextState.hasError
                          ? nextState.error.toString()
                          : 'El pasajero recibió la respuesta del conductor.',
                      type: nextState.hasError
                          ? AppSnackBarType.error
                          : AppSnackBarType.info,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _RequestSection(
                  title: 'Precio propuesto',
                  emptyText: 'Aún no hay solicitudes con precio propuesto',
                  requests: proposed,
                  color: AppColors.primary,
                  isBusy: requestState.isLoading,
                ),
                const SizedBox(height: 16),
                _RequestSection(
                  title: 'Aceptadas',
                  emptyText: 'Aún no hay solicitudes aceptadas',
                  requests: accepted,
                  color: AppColors.success,
                  isBusy: requestState.isLoading,
                ),
                const SizedBox(height: 16),
                _RequestSection(
                  title: 'Rechazadas',
                  emptyText: 'Aún no hay solicitudes rechazadas',
                  requests: rejected,
                  color: AppColors.error,
                  isBusy: requestState.isLoading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RequestSummary extends StatelessWidget {
  final int pending;
  final int proposed;
  final int accepted;
  final int rejected;

  const _RequestSummary({
    required this.pending,
    required this.proposed,
    required this.accepted,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Pendientes',
            value: pending,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Cotizadas',
            value: proposed,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Aceptadas',
            value: accepted,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
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

class _RequestSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<TripRequest> requests;
  final Color color;
  final bool isBusy;
  final Future<void> Function(TripRequest request)? onAccept;
  final Future<void> Function(TripRequest request)? onReject;

  const _RequestSection({
    required this.title,
    required this.emptyText,
    required this.requests,
    required this.color,
    required this.isBusy,
    this.onAccept,
    this.onReject,
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
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            Text(
              emptyText,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ...requests.map(
              (request) => _RequestCard(
                request: request,
                color: color,
                isBusy: isBusy,
                onAccept: onAccept == null ? null : () => onAccept!(request),
                onReject: onReject == null ? null : () => onReject!(request),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final TripRequest request;
  final Color color;
  final bool isBusy;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onReject;

  const _RequestCard({
    required this.request,
    required this.color,
    required this.isBusy,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengerAsync = ref.watch(profileProvider(request.passengerId));
    final passengerName = passengerAsync.maybeWhen(
      data: (profile) => profile.fullName.trim().isEmpty
          ? 'Pasajero'
          : profile.fullName.trim(),
      orElse: () => 'Pasajero',
    );
    final initials = passengerName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.16),
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: AppTextStyles.labelMedium.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  passengerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RequestInfoChip(
                icon: Icons.groups_outlined,
                label: '${request.passengerCount} pasajero(s)',
              ),
              if (request.proposedPrice != null)
                _RequestInfoChip(
                  icon: Icons.attach_money,
                  label:
                      '\$${request.proposedPrice!.toStringAsFixed(2)} por asiento',
                ),
            ],
          ),
          if ((request.pickupNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _RequestNote(
              label: 'Parada / recogida',
              value: request.pickupNote!,
            ),
          ],
          if ((request.dropoffNote ?? '').trim().isNotEmpty &&
              request.dropoffNote != request.pickupNote) ...[
            const SizedBox(height: 8),
            _RequestNote(
              label: 'Destino / parada final',
              value: request.dropoffNote!,
            ),
          ],
          if ((request.priceNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _RequestNote(label: 'Nota del precio', value: request.priceNote!),
          ],
          if (request.stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RequestStopsList(stops: request.stops),
            const SizedBox(height: 10),
            _RequestStopsMap(request: request),
          ],
          if (onAccept != null || onReject != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CustomButton(
                  label: AppStrings.accept,
                  width: 120,
                  isLoading: isBusy,
                  onPressed: isBusy ? null : () async => onAccept?.call(),
                ),
                CustomButton(
                  label: AppStrings.reject,
                  width: 120,
                  isOutlined: true,
                  onPressed: isBusy ? null : () async => onReject?.call(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestStopsList extends StatelessWidget {
  final List<TripRequestStop> stops;

  const _RequestStopsList({required this.stops});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paradas solicitadas',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < stops.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${i + 1}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stops[i].label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RequestStopsMap extends ConsumerWidget {
  final TripRequest request;

  const _RequestStopsMap({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(request.tripId));

    return tripAsync.maybeWhen(
      data: (trip) {
        if (trip.originLatitude == null ||
            trip.originLongitude == null ||
            trip.destinationLatitude == null ||
            trip.destinationLongitude == null) {
          return const SizedBox.shrink();
        }

        final origin = LatLng(trip.originLatitude!, trip.originLongitude!);
        final destination = LatLng(
          trip.destinationLatitude!,
          trip.destinationLongitude!,
        );
        final stopPoints = request.stops
            .map((stop) => LatLng(stop.latitude, stop.longitude))
            .toList();
        final routeAsync = ref.watch(
          routeInfoProvider(
            RouteRequest(
              origin: origin,
              destination: destination,
              waypoints: stopPoints,
            ),
          ),
        );
        final routePoints =
            routeAsync.asData?.value.points ??
            [origin, ...stopPoints, destination];

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(initialCenter: origin, initialZoom: 13),
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
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: origin,
                      width: 38,
                      height: 38,
                      child: const _MiniMapMarker(
                        icon: Icons.trip_origin,
                        color: AppColors.primary,
                      ),
                    ),
                    for (var i = 0; i < request.stops.length; i++)
                      Marker(
                        point: LatLng(
                          request.stops[i].latitude,
                          request.stops[i].longitude,
                        ),
                        width: 38,
                        height: 38,
                        child: _MiniNumberedMarker(index: i + 1),
                      ),
                    Marker(
                      point: destination,
                      width: 38,
                      height: 38,
                      child: const _MiniMapMarker(
                        icon: Icons.flag,
                        color: AppColors.primaryMid,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MiniMapMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniMapMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _MiniNumberedMarker extends StatelessWidget {
  final int index;

  const _MiniNumberedMarker({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$index',
          style: AppTextStyles.caption.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _RequestInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RequestInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _RequestNote extends StatelessWidget {
  final String label;
  final String value;

  const _RequestNote({required this.label, required this.value});

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
        Text(value, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
