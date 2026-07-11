import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/vehicle.dart';
import '../providers/vehicle_provider.dart';

/// Vehicle page showing the driver's registered vehicle or a registration prompt.
class VehiclePage extends ConsumerWidget {
  const VehiclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;

    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final profileAsync = ref.watch(profileProvider(userId));
    final role = profileAsync.asData?.value.role;

    if (role == AppStrings.rolePassenger) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_transfer,
                size: 64,
                color: AppColors.primaryLight,
              ),
              const SizedBox(height: 16),
              Text(
                'Esta sección es solo para conductores',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final vehicleAsync = ref.watch(myVehicleProvider(userId));
    final notifierState = ref.watch(vehicleNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi vehículo'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        actions: [
          if (vehicleAsync.asData?.value != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push(AppStrings.routeVehicleEdit),
            ),
          if (vehicleAsync.asData?.value != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: notifierState.isLoading
                  ? null
                  : () async {
                      final vehicle = vehicleAsync.asData!.value!;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Eliminar vehículo'),
                          content: const Text(
                            'Se eliminará el vehículo y pasarás a ser pasajero. '
                            'Para volver a ser conductor deberás registrar un '
                            'vehículo nuevo (con verificación).',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      await ref
                          .read(vehicleNotifierProvider.notifier)
                          .deleteVehicle(vehicle.id, userId);
                      final result = ref.read(vehicleNotifierProvider);
                      if (!context.mounted) return;
                      if (result.hasError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.error.toString())),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vehículo eliminado. Ahora eres pasajero.',
                          ),
                        ),
                      );
                      context.go(AppStrings.routeHome);
                    },
            ),
        ],
      ),
      body: vehicleAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (vehicle) {
          if (vehicle == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 72,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aún no tienes vehículo registrado',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Registrar mi vehículo',
                    onPressed: () => context.push(AppStrings.routeVehicleEdit),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: AppColors.surface,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (vehicle.photoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: vehicle.photoUrl!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_car,
                                size: 64,
                                color: AppColors.primaryMid,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _approvalColor(
                              vehicle.approvalStatus,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _approvalLabel(vehicle.approvalStatus),
                            style: AppTextStyles.caption.copyWith(
                              color: _approvalColor(vehicle.approvalStatus),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${vehicle.brand} ${vehicle.model}',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle.color} • Placa: ${vehicle.plate}',
                          style: AppTextStyles.bodySmall,
                        ),
                        if (vehicle.licensePhotoUrl != null) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Matrícula',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: vehicle.licensePhotoUrl!,
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: 'Editar vehículo',
                  isOutlined: true,
                  onPressed: () => context.push(AppStrings.routeVehicleEdit),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _approvalLabel(String status) {
  switch (status) {
    case VehicleApprovalStatus.approved:
      return 'Vehículo aprobado';
    case VehicleApprovalStatus.rejected:
      return 'Vehículo rechazado';
    default:
      return 'Aprobación pendiente';
  }
}

Color _approvalColor(String status) {
  switch (status) {
    case VehicleApprovalStatus.approved:
      return AppColors.success;
    case VehicleApprovalStatus.rejected:
      return AppColors.error;
    default:
      return AppColors.warning;
  }
}
