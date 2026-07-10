import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/vehicle_provider.dart';

/// Vehicle page showing the driver's registered vehicle or a registration prompt.
class VehiclePage extends ConsumerWidget {
  const VehiclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;

    if (userId == null) {
      return const Scaffold(body: SizedBox.shrink());
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi vehículo'),
        actions: [
          if (vehicleAsync.asData?.value != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push(AppStrings.routeVehicleEdit),
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
                        Text(
                          '${vehicle.brand} ${vehicle.model}',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vehicle.color} • Placa: ${vehicle.plate}',
                          style: AppTextStyles.bodySmall,
                        ),
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
