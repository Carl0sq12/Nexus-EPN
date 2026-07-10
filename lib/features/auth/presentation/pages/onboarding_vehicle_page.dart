import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
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
  bool _initialized = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result != null && mounted) setState(() => _photo = File(result.path));
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).value?.session?.user.id;
    final state = ref.watch(vehicleNotifierProvider);

    if (userId == null) return const Scaffold(body: SizedBox.shrink());

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
                'Para publicar viajes y aceptar pasajeros debes registrar tu vehículo con fotografía.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _photo == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 44,
                            color: AppColors.primary,
                          )
                        : Image.file(_photo!, fit: BoxFit.cover),
                  ),
                ),
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
                isLoading: state.isLoading,
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_photo == null && vehicle?.photoUrl == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('La fotografía es obligatoria'),
                            ),
                          );
                          return;
                        }
                        if (vehicle == null) {
                          await ref
                              .read(vehicleNotifierProvider.notifier)
                              .createVehicleWithPhoto(
                                userId,
                                _brandController.text.trim(),
                                _modelController.text.trim(),
                                _colorController.text.trim(),
                                _plateController.text.trim(),
                                _photo!,
                              );
                        } else {
                          final fields = <String, dynamic>{
                            'brand': _brandController.text.trim(),
                            'model': _modelController.text.trim(),
                            'color': _colorController.text.trim(),
                          };
                          if (_photo != null) {
                            final photoUrl = await ref
                                .read(vehicleRepositoryProvider)
                                .uploadVehiclePhoto(vehicle.id, _photo!);
                            fields['photo_url'] = photoUrl;
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
                        context.go(AppStrings.routeSplash);
                      },
              ),
            ],
          ),
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
