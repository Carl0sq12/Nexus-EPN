import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_limits.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';

/// Driver page for managing published trips.
class MyTripsPage extends ConsumerStatefulWidget {
  const MyTripsPage({super.key});

  @override
  ConsumerState<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends ConsumerState<MyTripsPage> {
  _TripListFilter _selectedFilter = _TripListFilter.readyToStart;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final notifierState = ref.watch(tripNotifierProvider);

    ref.listen(tripNotifierProvider, (previous, next) {
      if (next is AsyncError && context.mounted) {
        showAppSnackBar(
          context,
          title: 'No se pudo actualizar el viaje',
          message: next.error.toString(),
          type: AppSnackBarType.error,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis viajes'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Publicar viaje',
            icon: const Icon(Icons.add),
            onPressed: () => context.push(AppStrings.routeTripsNew),
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('Inicia sesión para ver tus viajes'))
          : ref
                .watch(myTripsProvider(userId))
                .when(
                  loading: () => const LoadingWidget(),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (trips) {
                    if (trips.isEmpty) {
                      return const Center(
                        child: Text(
                          'Todavía no has publicado viajes',
                          style: AppTextStyles.bodyMedium,
                        ),
                      );
                    }

                    final groupedTrips = _groupTrips(trips);
                    final visibleTrips = groupedTrips.forFilter(
                      _selectedFilter,
                    );

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(myTripsProvider(userId));
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _TripFilterBar(
                            selected: _selectedFilter,
                            groupedTrips: groupedTrips,
                            onChanged: (filter) {
                              setState(() => _selectedFilter = filter);
                            },
                          ),
                          const SizedBox(height: 16),
                          _SelectedFilterHeader(filter: _selectedFilter),
                          const SizedBox(height: 12),
                          if (visibleTrips.isEmpty)
                            _EmptyTripsFilter(filter: _selectedFilter)
                          else
                            ...visibleTrips.map(
                              (trip) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MyTripCard(
                                  trip: trip,
                                  isBusy: notifierState.isLoading,
                                  primaryLabel: _primaryLabelFor(
                                    _selectedFilter,
                                    trip,
                                  ),
                                  primaryIcon: _primaryIconFor(
                                    _selectedFilter,
                                    trip,
                                  ),
                                  onPrimary: () => _handlePrimaryAction(
                                    context,
                                    ref,
                                    trip,
                                    _selectedFilter,
                                  ),
                                  onRequests: () => context.push(
                                    '/trips/${trip.id}/requests',
                                  ),
                                  onEdit: () =>
                                      _showEditTripDialog(context, ref, trip),
                                  onCancel: () =>
                                      _confirmCancelTrip(context, ref, trip),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _showEditTripDialog(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final originController = TextEditingController(text: trip.origin);
    final destinationController = TextEditingController(text: trip.destination);
    final seatsController = TextEditingController(
      text: '${trip.totalSeats.clamp(1, AppLimits.maxTripSeats)}',
    );
    final priceController = TextEditingController(
      text: trip.pricePerSeat.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Editar viaje'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: originController,
                      decoration: const InputDecoration(labelText: 'Origen'),
                      validator: _requiredValidator,
                    ),
                    TextFormField(
                      controller: destinationController,
                      decoration: const InputDecoration(labelText: 'Destino'),
                      validator: _requiredValidator,
                    ),
                    TextFormField(
                      controller: seatsController,
                      decoration: const InputDecoration(
                        labelText: 'Asientos totales',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final seats = int.tryParse(value ?? '');
                        if (seats == null || seats <= 0) {
                          return 'Debe ser mayor a 0';
                        }
                        if (seats > AppLimits.maxTripSeats) {
                          return 'Máximo 4 asientos disponibles';
                        }
                        final occupiedSeats =
                            trip.totalSeats - trip.availableSeats;
                        if (seats < occupiedSeats) {
                          return 'Hay $occupiedSeats asientos ocupados';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio por asiento',
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final price = double.tryParse((value ?? '').trim());
                        if (price == null || price <= 0) {
                          return 'Debe ser mayor a 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text(AppStrings.save),
              ),
            ],
          );
        },
      );

      if (saved != true) return;

      final totalSeats = int.parse(seatsController.text.trim());
      final occupiedSeats = trip.totalSeats - trip.availableSeats;
      await ref
          .read(tripNotifierProvider.notifier)
          .updateTrip(trip.id, trip.driverId, {
            'origin': originController.text.trim(),
            'destination': destinationController.text.trim(),
            'total_seats': totalSeats,
            'available_seats': totalSeats - occupiedSeats,
            'price_per_seat': double.parse(priceController.text.trim()),
          });

      if (context.mounted) {
        showAppSnackBar(
          context,
          title: 'Viaje actualizado',
          message: 'Los cambios quedaron guardados correctamente.',
          type: AppSnackBarType.success,
        );
      }
    } finally {
      originController.dispose();
      destinationController.dispose();
      seatsController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _confirmCancelTrip(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar viaje'),
        content: const Text('¿Estás seguro de cancelar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref
        .read(tripNotifierProvider.notifier)
        .deleteTrip(trip.id, trip.driverId);

    if (context.mounted) {
      showAppSnackBar(
        context,
        title: 'Viaje cancelado',
        message: 'El viaje fue retirado y ya no recibirá solicitudes.',
        type: AppSnackBarType.info,
      );
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }

  Future<void> _startTripFromList(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    await ref.read(tripNotifierProvider.notifier).updateTrip(
      trip.id,
      trip.driverId,
      {'status': AppStrings.statusInProgress},
    );

    if (!context.mounted) return;
    final state = ref.read(tripNotifierProvider);
    if (state.hasError) {
      showAppSnackBar(
        context,
        title: 'No se inició el viaje',
        message: state.error.toString(),
        type: AppSnackBarType.error,
      );
      return;
    }
    context.push('/trips/${trip.id}/navigation');
  }

  void _handlePrimaryAction(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
    _TripListFilter filter,
  ) {
    switch (filter) {
      case _TripListFilter.readyToStart:
        _startTripFromList(context, ref, trip);
      case _TripListFilter.inProgress:
        context.push('/trips/${trip.id}/navigation');
      case _TripListFilter.finished:
        if (trip.status == AppStrings.statusCompleted) {
          context.push('/trips/${trip.id}/report');
        } else {
          context.push('/trips/${trip.id}');
        }
      case _TripListFilter.published:
        context.push('/trips/${trip.id}');
    }
  }
}

enum _TripListFilter { readyToStart, inProgress, finished, published }

String _primaryLabelFor(_TripListFilter filter, Trip trip) {
  return switch (filter) {
    _TripListFilter.readyToStart => 'Iniciar',
    _TripListFilter.inProgress => 'Navegar',
    _TripListFilter.finished =>
      trip.status == AppStrings.statusCompleted ? 'Reporte' : 'Detalle',
    _TripListFilter.published => 'Detalle',
  };
}

IconData _primaryIconFor(_TripListFilter filter, Trip trip) {
  return switch (filter) {
    _TripListFilter.readyToStart => Icons.play_arrow,
    _TripListFilter.inProgress => Icons.navigation_outlined,
    _TripListFilter.finished =>
      trip.status == AppStrings.statusCompleted
          ? Icons.assessment_outlined
          : Icons.info_outline,
    _TripListFilter.published => Icons.info_outline,
  };
}

_GroupedTrips _groupTrips(List<Trip> trips) {
  final readyToStart = <Trip>[];
  final inProgress = <Trip>[];
  final published = <Trip>[];
  final finished = <Trip>[];

  for (final trip in trips) {
    if (trip.status == AppStrings.statusCompleted ||
        trip.status == AppStrings.statusCancelled) {
      finished.add(trip);
    } else if (trip.status == AppStrings.statusInProgress) {
      inProgress.add(trip);
    } else if (trip.status == AppStrings.statusFull ||
        (trip.status == AppStrings.statusActive && trip.availableSeats == 0)) {
      readyToStart.add(trip);
    } else {
      published.add(trip);
    }
  }

  int newestFirst(Trip a, Trip b) => b.departureTime.compareTo(a.departureTime);
  int oldestFirst(Trip a, Trip b) => a.departureTime.compareTo(b.departureTime);

  readyToStart.sort(oldestFirst);
  inProgress.sort(oldestFirst);
  published.sort(oldestFirst);
  finished.sort(newestFirst);

  return _GroupedTrips(
    readyToStart: readyToStart,
    inProgress: inProgress,
    published: published,
    finished: finished,
  );
}

class _GroupedTrips {
  final List<Trip> readyToStart;
  final List<Trip> inProgress;
  final List<Trip> published;
  final List<Trip> finished;

  const _GroupedTrips({
    required this.readyToStart,
    required this.inProgress,
    required this.published,
    required this.finished,
  });

  List<Trip> forFilter(_TripListFilter filter) {
    return switch (filter) {
      _TripListFilter.readyToStart => readyToStart,
      _TripListFilter.inProgress => inProgress,
      _TripListFilter.finished => finished,
      _TripListFilter.published => published,
    };
  }

  int countFor(_TripListFilter filter) => forFilter(filter).length;
}

class _TripFilterBar extends StatelessWidget {
  final _TripListFilter selected;
  final _GroupedTrips groupedTrips;
  final ValueChanged<_TripListFilter> onChanged;

  const _TripFilterBar({
    required this.selected,
    required this.groupedTrips,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      _TripListFilter.readyToStart,
      _TripListFilter.inProgress,
      _TripListFilter.finished,
      _TripListFilter.published,
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selected == filter;
          return ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              _filterIcon(filter),
              size: 18,
              color: isSelected ? AppColors.onPrimary : AppColors.primary,
            ),
            label: Text(
              '${_filterLabel(filter)} (${groupedTrips.countFor(filter)})',
              overflow: TextOverflow.ellipsis,
            ),
            labelStyle: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? AppColors.onPrimary : AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (_) => onChanged(filter),
          );
        },
      ),
    );
  }
}

class _SelectedFilterHeader extends StatelessWidget {
  final _TripListFilter filter;

  const _SelectedFilterHeader({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_filterIcon(filter), color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_filterTitle(filter), style: AppTextStyles.titleMedium),
              const SizedBox(height: 2),
              Text(
                _filterSubtitle(filter),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTripsFilter extends StatelessWidget {
  final _TripListFilter filter;

  const _EmptyTripsFilter({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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

String _filterLabel(_TripListFilter filter) {
  return switch (filter) {
    _TripListFilter.readyToStart => 'Listos',
    _TripListFilter.inProgress => 'En curso',
    _TripListFilter.finished => 'Finalizados',
    _TripListFilter.published => 'Publicados',
  };
}

String _filterTitle(_TripListFilter filter) {
  return switch (filter) {
    _TripListFilter.readyToStart => 'Completos para iniciar navegación',
    _TripListFilter.inProgress => 'Viajes en curso',
    _TripListFilter.finished => 'Viajes finalizados',
    _TripListFilter.published => 'Viajes publicados',
  };
}

String _filterSubtitle(_TripListFilter filter) {
  return switch (filter) {
    _TripListFilter.readyToStart =>
      'Viajes con cupos llenos, listos para salir.',
    _TripListFilter.inProgress =>
      'Viajes iniciados que todavía están navegando.',
    _TripListFilter.finished => 'Historial de viajes completados o cancelados.',
    _TripListFilter.published => 'Viajes activos que aún aceptan solicitudes.',
  };
}

String _emptyText(_TripListFilter filter) {
  return switch (filter) {
    _TripListFilter.readyToStart => 'No tienes viajes completos por iniciar.',
    _TripListFilter.inProgress => 'No tienes viajes en curso.',
    _TripListFilter.finished => 'No tienes viajes finalizados.',
    _TripListFilter.published => 'No tienes viajes publicados activos.',
  };
}

IconData _filterIcon(_TripListFilter filter) {
  return switch (filter) {
    _TripListFilter.readyToStart => Icons.play_circle_outline,
    _TripListFilter.inProgress => Icons.navigation_outlined,
    _TripListFilter.finished => Icons.task_alt_outlined,
    _TripListFilter.published => Icons.event_available_outlined,
  };
}

class _MyTripCard extends StatelessWidget {
  final Trip trip;
  final bool isBusy;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final VoidCallback onRequests;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _MyTripCard({
    required this.trip,
    required this.isBusy,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onRequests,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      'dd MMM yyyy · HH:mm',
    ).format(trip.departureTime);
    final canModify =
        trip.status == AppStrings.statusActive ||
        trip.status == AppStrings.statusFull;

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
              Expanded(
                child: Text(
                  '${trip.origin} → ${trip.destination}',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              _StatusChip(status: trip.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formattedDate,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoPill(
                icon: Icons.people_outline,
                label: '${trip.availableSeats}/${trip.totalSeats} cupos',
              ),
              const SizedBox(width: 8),
              _InfoPill(
                icon: Icons.payments_outlined,
                label: '\$${trip.pricePerSeat.toStringAsFixed(2)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CustomButton(
                label: 'Solicitudes',
                width: 140,
                onPressed: onRequests,
              ),
              CustomButton(
                label: primaryLabel,
                leadingIcon: primaryIcon,
                width: 120,
                isOutlined: true,
                isLoading: isBusy && trip.status == AppStrings.statusFull,
                onPressed: isBusy ? null : onPrimary,
              ),
              CustomButton(
                label: AppStrings.edit,
                width: 110,
                isOutlined: true,
                onPressed: canModify && !isBusy ? onEdit : null,
              ),
              CustomButton(
                label: 'Cancelar',
                width: 120,
                isOutlined: true,
                onPressed: canModify && !isBusy ? onCancel : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

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

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppStrings.statusActive => AppColors.primary,
      AppStrings.statusFull => AppColors.warning,
      AppStrings.statusInProgress => AppColors.success,
      AppStrings.statusCompleted => AppColors.textSecondary,
      AppStrings.statusCancelled => AppColors.error,
      _ => AppColors.textSecondary,
    };
    final label = switch (status) {
      AppStrings.statusActive => 'Activo',
      AppStrings.statusFull => 'Completo',
      AppStrings.statusInProgress => 'En curso',
      AppStrings.statusCompleted => 'Completado',
      AppStrings.statusCancelled => 'Cancelado',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
