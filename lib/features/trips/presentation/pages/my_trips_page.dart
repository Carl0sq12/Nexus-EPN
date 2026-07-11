import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';

/// Driver page for managing published trips.
class MyTripsPage extends ConsumerWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final notifierState = ref.watch(tripNotifierProvider);

    ref.listen(tripNotifierProvider, (previous, next) {
      if (next is AsyncError && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
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

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(myTripsProvider(userId));
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: trips.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _MyTripCard(
                            trip: trips[index],
                            isBusy: notifierState.isLoading,
                            onDetails: () =>
                                context.push('/trips/${trips[index].id}'),
                            onRequests: () => context.push(
                              '/trips/${trips[index].id}/requests',
                            ),
                            onReport: () => context.push(
                              '/trips/${trips[index].id}/report',
                            ),
                            onEdit: () =>
                                _showEditTripDialog(context, ref, trips[index]),
                            onCancel: () =>
                                _confirmCancelTrip(context, ref, trips[index]),
                          );
                        },
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
    final seatsController = TextEditingController(text: '${trip.totalSeats}');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Viaje actualizado')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Viaje cancelado')));
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }
}

class _MyTripCard extends StatelessWidget {
  final Trip trip;
  final bool isBusy;
  final VoidCallback onDetails;
  final VoidCallback onRequests;
  final VoidCallback onReport;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _MyTripCard({
    required this.trip,
    required this.isBusy,
    required this.onDetails,
    required this.onRequests,
    required this.onReport,
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
                label: trip.status == AppStrings.statusInProgress
                    ? 'Navegar'
                    : trip.availableSeats == 0
                    ? 'Ver ruta'
                    : 'Detalle',
                width: 120,
                isOutlined: true,
                onPressed: onDetails,
              ),
              if (trip.status == AppStrings.statusCompleted)
                CustomButton(
                  label: 'Reporte',
                  width: 110,
                  isOutlined: true,
                  onPressed: onReport,
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
