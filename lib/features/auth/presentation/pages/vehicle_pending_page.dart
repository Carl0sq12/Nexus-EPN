import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../vehicles/presentation/providers/vehicle_provider.dart';
import '../providers/auth_provider.dart';

/// Shown while a driver's vehicle awaits admin approval.
class VehiclePendingPage extends ConsumerWidget {
  const VehiclePendingPage({super.key});

  Future<void> _continueAsPassenger(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Continuar como pasajero'),
        content: const Text(
          'Se eliminará el vehículo pendiente y tu cuenta quedará como pasajero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, ser pasajero'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final vehicle = await ref.read(myVehicleProvider(userId).future);
    if (vehicle != null) {
      await ref
          .read(vehicleNotifierProvider.notifier)
          .deleteVehicle(vehicle.id, userId);
      final result = ref.read(vehicleNotifierProvider);
      if (result.hasError) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error.toString())),
          );
        }
        return;
      }
    }
    ref.invalidate(onboardingStatusProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Continúas como pasajero')),
    );
    context.go(AppStrings.routeSplash);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Vehículo en verificación',
                style: AppTextStyles.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Tu vehículo está pendiente de verificación. '
                'No puedes publicar viajes ni entrar al Home de conductor '
                'hasta que sea aprobado.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Ya me aprobaron',
                onPressed: () {
                  ref.invalidate(onboardingStatusProvider);
                  context.go(AppStrings.routeSplash);
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _continueAsPassenger(context, ref),
                child: const Text('Continuar como pasajero'),
              ),
              const SizedBox(height: 8),
              CustomButton(
                label: AppStrings.logout,
                isOutlined: true,
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go(AppStrings.routeLogin);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
