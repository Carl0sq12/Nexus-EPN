import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/utils/image_sharpness.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicle_provider.dart';

/// Mandatory driver vehicle registration before Home or driver-only features.
class OnboardingVehiclePage extends ConsumerStatefulWidget {
  const OnboardingVehiclePage({super.key});

  @override
  ConsumerState<OnboardingVehiclePage> createState() =>
      _OnboardingVehiclePageState();
}

class _OnboardingVehiclePageState extends ConsumerState<OnboardingVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  File? _photo;
  File? _licensePhoto;
  bool _initialized = false;
  bool _switchingToPassenger = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isLicense}) async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return;
    final file = File(result.path);
    final isSharp = await ImageSharpness.isSharp(file);
    if (!mounted) return;
    if (!isSharp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La foto está borrosa. Toma otra con buena luz y enfoque.',
          ),
        ),
      );
      return;
    }
    setState(() {
      if (isLicense) {
        _licensePhoto = file;
      } else {
        _photo = file;
      }
    });
  }

  Future<void> _continueAsPassenger(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Continuar como pasajero'),
        content: const Text(
          'No registrarás vehículo y tu cuenta quedará como pasajero. '
          'Podrás convertirte en conductor más adelante desde tu perfil.',
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
    if (confirmed != true) return;

    setState(() => _switchingToPassenger = true);
    try {
      final vehicle = ref.read(myVehicleProvider(userId)).asData?.value;
      if (vehicle != null) {
        await ref
            .read(vehicleNotifierProvider.notifier)
            .deleteVehicle(vehicle.id, userId);
        final deleteResult = ref.read(vehicleNotifierProvider);
        if (deleteResult.hasError) {
          throw deleteResult.error!;
        }
      } else {
        await ref.read(profileNotifierProvider.notifier).updateProfile(
              userId,
              role: AppStrings.rolePassenger,
            );
        final profileResult = ref.read(profileNotifierProvider);
        if (profileResult.hasError) {
          throw profileResult.error!;
        }
      }
      ref.invalidate(onboardingStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Continúas como pasajero')),
      );
      context.go(AppStrings.routeSplash);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _switchingToPassenger = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final state = ref.watch(vehicleNotifierProvider);
    final busy = state.isLoading || _switchingToPassenger;

    if (userId == null) {
      return const Scaffold(body: AppLoadingView(message: 'Cargando sesión...'));
    }

    final vehicleAsync = ref.watch(myVehicleProvider(userId));
    final vehicle = vehicleAsync.asData?.value;
    if (vehicle != null && !_initialized) {
      _initialized = true;
      _brandController.text = vehicle.brand;
      _modelController.text = vehicle.model;
      _colorController.text = vehicle.color;
      _plateController.text = vehicle.plate;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Registrar vehículo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehículo obligatorio',
                style: AppTextStyles.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Para publicar viajes y aceptar pasajeros debes registrar tu vehículo con fotografía. '
                'El registro nuevo requiere verificación.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _PhotoField(
                    label: 'Vehículo',
                    file: _photo,
                    icon: Icons.directions_car_outlined,
                    onTap: () => _pickPhoto(isLicense: false),
                  ),
                  const SizedBox(width: 16),
                  _PhotoField(
                    label: 'Licencia',
                    file: _licensePhoto,
                    icon: Icons.badge_outlined,
                    onTap: () => _pickPhoto(isLicense: true),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _VehicleField(
                controller: _brandController,
                icon: Icons.directions_car_outlined,
                label: 'Marca',
              ),
              const SizedBox(height: 16),
              _VehicleField(
                controller: _modelController,
                icon: Icons.build_outlined,
                label: 'Modelo',
              ),
              const SizedBox(height: 16),
              _VehicleField(
                controller: _colorController,
                icon: Icons.color_lens_outlined,
                label: 'Color',
              ),
              const SizedBox(height: 16),
              _VehicleField(
                controller: _plateController,
                icon: Icons.pin_outlined,
                label: 'Matrícula',
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: AppStrings.save,
                isLoading: busy,
                onPressed: busy
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if ((_photo == null && vehicle?.photoUrl == null) ||
                            (_licensePhoto == null &&
                                vehicle?.licensePhotoUrl == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Las fotos del vehículo y licencia son obligatorias.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (vehicle == null) {
                          if (_photo == null || _licensePhoto == null) return;
                          await ref
                              .read(vehicleNotifierProvider.notifier)
                              .createVehicleWithPhotos(
                                userId,
                                _brandController.text.trim(),
                                _modelController.text.trim(),
                                _colorController.text.trim(),
                                _plateController.text.trim(),
                                _photo!,
                                _licensePhoto!,
                              );
                        } else {
                          // Completing an incomplete registration → pending again.
                          final fields = <String, dynamic>{
                            'brand': _brandController.text.trim(),
                            'model': _modelController.text.trim(),
                            'color': _colorController.text.trim(),
                            'plate': _plateController.text.trim(),
                            'approval_status': VehicleApprovalStatus.pending,
                          };
                          final repository = ref.read(
                            vehicleRepositoryProvider,
                          );
                          if (_photo != null) {
                            fields['photo_url'] =
                                await repository.uploadVehiclePhoto(
                              vehicle.id,
                              _photo!,
                              previousUrl: vehicle.photoUrl,
                              ownerUserId: userId,
                            );
                          }
                          if (_licensePhoto != null) {
                            fields['license_photo_url'] =
                                await repository.uploadLicensePhoto(
                              vehicle.id,
                              _licensePhoto!,
                              previousUrl: vehicle.licensePhotoUrl,
                              ownerUserId: userId,
                            );
                          }
                          await ref
                              .read(vehicleNotifierProvider.notifier)
                              .updateVehicle(vehicle.id, userId, fields);
                        }
                        final nextState = ref.read(vehicleNotifierProvider);
                        if (!context.mounted) return;
                        if (nextState.hasError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(nextState.error.toString())),
                          );
                          return;
                        }
                        ref.invalidate(onboardingStatusProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Registro enviado. Tu vehículo está pendiente de aprobación.',
                            ),
                          ),
                        );
                        context.go(AppStrings.routeOnboardingVehiclePending);
                      },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: busy ? null : () => _continueAsPassenger(userId),
                  child: const Text('Continuar como pasajero'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  final String label;
  final File? file;
  final IconData icon;
  final VoidCallback onTap;

  const _PhotoField({
    required this.label,
    required this.file,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: file == null
                  ? Center(
                      child: Icon(icon, size: 44, color: AppColors.primary),
                    )
                  : Image.file(
                      file!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _VehicleField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String label;

  const _VehicleField({
    required this.controller,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Campo requerido';
        return null;
      },
    );
  }
}
