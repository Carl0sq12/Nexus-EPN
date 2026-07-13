import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_provider.dart';
import '../../domain/entities/trip_request.dart';
import '../providers/request_provider.dart';
import 'driver_requests_page.dart';

/// Role-aware requests inbox: drivers see incoming, passengers see their own.
class RequestsInboxPage extends ConsumerWidget {
  const RequestsInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final profileAsync = ref.watch(profileProvider(userId));
    return profileAsync.when(
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (profile) {
        if (profile.role == AppStrings.roleDriver) {
          return const DriverRequestsPage();
        }
        return const _PassengerRequestsPage();
      },
    );
  }
}

final _passengerRequestItemsProvider =
    StreamProvider.family<List<_PassengerRequestItem>, String>((ref, userId) {
      final requestRepository = ref.watch(requestRepositoryProvider);
      final tripRepository = ref.watch(tripRepositoryProvider);

      Future<List<_PassengerRequestItem>> load() async {
        final requests = await requestRepository.getMyRequests(userId);
        final items = <_PassengerRequestItem>[];
        for (final request in requests) {
          try {
            final trip = await tripRepository.getTripById(request.tripId);
            items.add(_PassengerRequestItem(request: request, trip: trip));
          } catch (_) {
            items.add(_PassengerRequestItem(request: request));
          }
        }
        return items;
      }

      return _watchPassengerRequestItems(load);
    });

class _PassengerRequestItem {
  final TripRequest request;
  final Trip? trip;

  const _PassengerRequestItem({required this.request, this.trip});
}

class _PassengerRequestsPage extends ConsumerStatefulWidget {
  const _PassengerRequestsPage();

  @override
  ConsumerState<_PassengerRequestsPage> createState() =>
      _PassengerRequestsPageState();
}

class _PassengerRequestsPageState
    extends ConsumerState<_PassengerRequestsPage> {
  _PassengerRequestFilter _selectedFilter = _PassengerRequestFilter.inProgress;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final itemsAsync = ref.watch(_passengerRequestItemsProvider(userId));
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.requestsTitle),
        automaticallyImplyLeading: canPop,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Buscar viajes',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppStrings.routeTripsSearch),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_passengerRequestItemsProvider(userId)),
        ),
        data: (items) {
          final visible =
              items.where((item) => _shouldShowRequest(item.request)).toList()
                ..sort(_sortPassengerItems);

          if (visible.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send_outlined,
                      size: 56,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no tienes solicitudes de cupo.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () =>
                          context.push(AppStrings.routeTripsSearch),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar un viaje'),
                    ),
                  ],
                ),
              ),
            );
          }

          final grouped = _GroupedPassengerRequests(visible);
          final currentTrip = grouped.inProgress.firstOrNull;
          final effectiveFilter = grouped.effectiveFilter(_selectedFilter);
          final selectedItems = grouped.forFilter(effectiveFilter);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_passengerRequestItemsProvider(userId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (currentTrip != null) ...[
                  _CurrentPassengerTripCard(item: currentTrip),
                  const SizedBox(height: 16),
                ],
                _PassengerRequestFilterBar(
                  selected: effectiveFilter,
                  grouped: grouped,
                  onChanged: (filter) =>
                      setState(() => _selectedFilter = filter),
                ),
                const SizedBox(height: 16),
                _PassengerFilterHeader(filter: effectiveFilter),
                const SizedBox(height: 12),
                if (selectedItems.isEmpty)
                  _EmptyPassengerRequestFilter(filter: effectiveFilter)
                else
                  for (final item in selectedItems) ...[
                    _PassengerRequestCard(item: item),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CurrentPassengerTripCard extends ConsumerWidget {
  final _PassengerRequestItem item;

  const _CurrentPassengerTripCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = item.trip;
    if (trip == null) return const SizedBox.shrink();
    final driverName = _driverName(ref, trip.driverId);
    final timeLabel = DateFormat('hh:mm a').format(trip.departureTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(13, 111, 148, 0.10),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.navigation, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Viaje en curso', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '$timeLabel · Conductor: $driverName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: 'En curso', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${trip.origin} → ${trip.destination}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 14),
          CustomButton(
            label: 'Ver ruta en vivo',
            leadingIcon: Icons.navigation_outlined,
            onPressed: () => context.push('/trips/${trip.id}/navigation'),
          ),
        ],
      ),
    );
  }
}

class _PassengerRequestFilterBar extends StatelessWidget {
  final _PassengerRequestFilter selected;
  final _GroupedPassengerRequests grouped;
  final ValueChanged<_PassengerRequestFilter> onChanged;

  const _PassengerRequestFilterBar({
    required this.selected,
    required this.grouped,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _PassengerRequestFilter.values) ...[
            ChoiceChip(
              selected: selected == filter,
              onSelected: (_) => onChanged(filter),
              avatar: Icon(
                _filterIcon(filter),
                size: 18,
                color: selected == filter ? Colors.white : AppColors.primary,
              ),
              label: Text('${_filterLabel(filter)} (${grouped.count(filter)})'),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              labelStyle: AppTextStyles.bodySmall.copyWith(
                color: selected == filter ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected == filter
                    ? AppColors.primary
                    : AppColors.outlineVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PassengerFilterHeader extends StatelessWidget {
  final _PassengerRequestFilter filter;

  const _PassengerFilterHeader({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_filterIcon(filter), color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_filterTitle(filter), style: AppTextStyles.titleMedium),
        ),
      ],
    );
  }
}

class _EmptyPassengerRequestFilter extends StatelessWidget {
  final _PassengerRequestFilter filter;

  const _EmptyPassengerRequestFilter({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(_filterIcon(filter), color: AppColors.primaryLight, size: 42),
          const SizedBox(height: 10),
          Text(
            _emptyText(filter),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerRequestCard extends ConsumerWidget {
  final _PassengerRequestItem item;

  const _PassengerRequestCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = item.request;
    final trip = item.trip;
    final routeLabel = trip == null
        ? 'Viaje ${request.tripId}'
        : '${trip.origin} → ${trip.destination}';
    final timeLabel = DateFormat(
      'dd/MM HH:mm',
    ).format((trip?.departureTime ?? request.createdAt).toLocal());
    final driverName = trip == null
        ? 'Conductor'
        : _driverName(ref, trip.driverId);
    final status = _passengerItemStatus(item);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (status.isInProgress && trip != null) {
            context.push('/trips/${trip.id}/navigation');
            return;
          }
          context.push('${AppStrings.routeRequests}/${request.id}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(status.icon, color: status.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeLabel,
                      style: AppTextStyles.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeLabel · $driverName · ${request.passengerCount} cupo(s)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _StatusBadge(label: status.label, color: status.color),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GroupedPassengerRequests {
  final List<_PassengerRequestItem> items;

  _GroupedPassengerRequests(this.items);

  List<_PassengerRequestItem> get inProgress => items
      .where(
        (item) => _filterForItem(item) == _PassengerRequestFilter.inProgress,
      )
      .toList();

  List<_PassengerRequestItem> get accepted => items
      .where((item) => _filterForItem(item) == _PassengerRequestFilter.accepted)
      .toList();

  List<_PassengerRequestItem> get pending => items
      .where((item) => _filterForItem(item) == _PassengerRequestFilter.pending)
      .toList();

  List<_PassengerRequestItem> get finished => items
      .where((item) => _filterForItem(item) == _PassengerRequestFilter.finished)
      .toList();

  List<_PassengerRequestItem> forFilter(_PassengerRequestFilter filter) {
    return switch (filter) {
      _PassengerRequestFilter.inProgress => inProgress,
      _PassengerRequestFilter.accepted => accepted,
      _PassengerRequestFilter.pending => pending,
      _PassengerRequestFilter.finished => finished,
    };
  }

  int count(_PassengerRequestFilter filter) => forFilter(filter).length;

  _PassengerRequestFilter effectiveFilter(_PassengerRequestFilter selected) {
    if (count(selected) > 0) return selected;
    for (final filter in _PassengerRequestFilter.values) {
      if (count(filter) > 0) return filter;
    }
    return selected;
  }
}

enum _PassengerRequestFilter { inProgress, accepted, pending, finished }

_PassengerRequestFilter _filterForItem(_PassengerRequestItem item) {
  final request = item.request;
  final trip = item.trip;
  if (request.status == AppStrings.statusPending ||
      request.status == AppStrings.statusPriceProposed) {
    return _PassengerRequestFilter.pending;
  }
  if (request.status == AppStrings.statusRejected ||
      request.status == AppStrings.statusCancelled ||
      request.status == AppStrings.statusCompleted ||
      trip?.status == AppStrings.statusCompleted ||
      trip?.status == AppStrings.statusCancelled) {
    return _PassengerRequestFilter.finished;
  }
  if (request.status == AppStrings.statusAccepted &&
      trip?.status == AppStrings.statusInProgress) {
    return _PassengerRequestFilter.inProgress;
  }
  return _PassengerRequestFilter.accepted;
}

_PassengerItemStatus _passengerItemStatus(_PassengerRequestItem item) {
  final request = item.request;
  final trip = item.trip;
  if (request.status == AppStrings.statusPriceProposed) {
    return const _PassengerItemStatus(
      label: 'Precio propuesto',
      icon: Icons.payments_outlined,
      color: AppColors.primary,
    );
  }
  if (request.status == AppStrings.statusPending) {
    return const _PassengerItemStatus(
      label: 'Pendiente',
      icon: Icons.hourglass_top,
      color: AppColors.warning,
    );
  }
  if (request.status == AppStrings.statusRejected) {
    return const _PassengerItemStatus(
      label: 'Rechazada',
      icon: Icons.cancel_outlined,
      color: AppColors.error,
    );
  }
  if (request.status == AppStrings.statusCancelled ||
      trip?.status == AppStrings.statusCancelled) {
    return const _PassengerItemStatus(
      label: 'Cancelada',
      icon: Icons.block,
      color: AppColors.error,
    );
  }
  if (request.status == AppStrings.statusCompleted ||
      trip?.status == AppStrings.statusCompleted) {
    return const _PassengerItemStatus(
      label: 'Finalizada',
      icon: Icons.check_circle_outline,
      color: AppColors.textSecondary,
    );
  }
  if (trip?.status == AppStrings.statusInProgress) {
    return const _PassengerItemStatus(
      label: 'En curso',
      icon: Icons.navigation_outlined,
      color: AppColors.success,
    );
  }
  return const _PassengerItemStatus(
    label: 'Aceptada',
    icon: Icons.event_available_outlined,
    color: AppColors.success,
  );
}

class _PassengerItemStatus {
  final String label;
  final IconData icon;
  final Color color;
  final bool isInProgress;

  const _PassengerItemStatus({
    required this.label,
    required this.icon,
    required this.color,
  }) : isInProgress = label == 'En curso';
}

bool _shouldShowRequest(TripRequest request) {
  return request.status == AppStrings.statusPending ||
      request.status == AppStrings.statusPriceProposed ||
      request.status == AppStrings.statusAccepted ||
      request.status == AppStrings.statusRejected ||
      request.status == AppStrings.statusCancelled ||
      request.status == AppStrings.statusCompleted;
}

int _sortPassengerItems(_PassengerRequestItem a, _PassengerRequestItem b) {
  final filterA = _filterForItem(a);
  final filterB = _filterForItem(b);
  if (filterA != filterB) {
    return filterA.index.compareTo(filterB.index);
  }
  final timeA = a.trip?.departureTime ?? a.request.createdAt;
  final timeB = b.trip?.departureTime ?? b.request.createdAt;
  return timeB.compareTo(timeA);
}

String _driverName(WidgetRef ref, String driverId) {
  final profile = ref.watch(profileProvider(driverId)).asData?.value;
  final name = profile?.fullName.trim();
  return name == null || name.isEmpty ? 'Conductor' : name;
}

String _filterLabel(_PassengerRequestFilter filter) {
  return switch (filter) {
    _PassengerRequestFilter.inProgress => 'En curso',
    _PassengerRequestFilter.accepted => 'Aceptados',
    _PassengerRequestFilter.pending => 'Pendientes',
    _PassengerRequestFilter.finished => 'Finalizados',
  };
}

String _filterTitle(_PassengerRequestFilter filter) {
  return switch (filter) {
    _PassengerRequestFilter.inProgress => 'Viajes en curso',
    _PassengerRequestFilter.accepted => 'Viajes aceptados',
    _PassengerRequestFilter.pending => 'Solicitudes pendientes',
    _PassengerRequestFilter.finished => 'Historial finalizado',
  };
}

String _emptyText(_PassengerRequestFilter filter) {
  return switch (filter) {
    _PassengerRequestFilter.inProgress =>
      'No tienes viajes en curso en este momento.',
    _PassengerRequestFilter.accepted =>
      'No tienes viajes aceptados esperando inicio.',
    _PassengerRequestFilter.pending => 'No tienes solicitudes pendientes.',
    _PassengerRequestFilter.finished =>
      'Aún no tienes viajes finalizados o cancelados.',
  };
}

IconData _filterIcon(_PassengerRequestFilter filter) {
  return switch (filter) {
    _PassengerRequestFilter.inProgress => Icons.navigation_outlined,
    _PassengerRequestFilter.accepted => Icons.event_available_outlined,
    _PassengerRequestFilter.pending => Icons.hourglass_top,
    _PassengerRequestFilter.finished => Icons.history,
  };
}

Stream<List<_PassengerRequestItem>> _watchPassengerRequestItems(
  Future<List<_PassengerRequestItem>> Function() load,
) async* {
  List<_PassengerRequestItem>? lastGood;
  while (true) {
    try {
      lastGood = await load();
      yield lastGood;
    } catch (e, st) {
      if (lastGood == null) {
        Error.throwWithStackTrace(e, st);
      }
      yield lastGood;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}
