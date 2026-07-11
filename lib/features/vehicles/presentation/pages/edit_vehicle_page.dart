import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/utils/image_sharpness.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../providers/vehicle_provider.dart';

/// Create or edit vehicle page with photo upload and form fields.
///
/// In edit mode only photos are updatable and approval is preserved.
/// Creating a vehicle (first time or after delete) requires verification.
class EditVehiclePage extends ConsumerStatefulWidget {
  const EditVehiclePage({super.key});

  @override
  ConsumerState<EditVehiclePage> createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends ConsumerState<EditVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  String? _localPhotoUrl;
  String? _localLicensePhotoUrl;
  File? _pickedPhotoFile;
  File? _pickedLicensePhotoFile;
  bool _initialized = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isLicense}) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
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
        _pickedLicensePhotoFile = file;
      } else {
        _pickedPhotoFile = file;
      }
    });
  }

  Widget _photoPicker({
    required String label,
    required bool isLicense,
    required File? file,
    required String? networkUrl,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _pickPhoto(isLicense: isLicense),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primarySoft,
              ),
              clipBehavior: Clip.antiAlias,
              child: file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : networkUrl != null
                  ? CachedNetworkImage(imageUrl: networkUrl, fit: BoxFit.cover)
                  : Center(
                      child: Icon(
                        isLicense ? Icons.badge_outlined : Icons.add_a_photo,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required IconData prefixIcon,
    required String labelText,
    bool readOnly = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: readOnly ? AppColors.outlineVariant : AppColors.primarySoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.secondary),
      suffixIcon: readOnly
          ? const Icon(Icons.lock_outline, size: 18, color: AppColors.secondary)
          : null,
      labelText: labelText,
    );
  }

  Future<void> _deleteVehicle(String vehicleId, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: const Text(
          'Se eliminará el vehículo y pasarás a ser pasajero. '
          'Si más adelante quieres volver a ser conductor, deberás '
          'registrar un vehículo nuevo (con verificación).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(vehicleNotifierProvider.notifier)
        .deleteVehicle(vehicleId, userId);
    final result = ref.read(vehicleNotifierProvider);
    if (!mounted) return;
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error.toString())),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vehículo eliminado. Ahora eres pasajero.'),
      ),
    );
    context.go(AppStrings.routeHome);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;

    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final vehicleAsync = ref.watch(myVehicleProvider(userId));
    final vehicle = vehicleAsync.asData?.value;
    final isEditMode = vehicle != null;
    final notifierState = ref.watch(vehicleNotifierProvider);

    if (vehicle != null && !_initialized) {
      _initialized = true;
      _brandController.text = vehicle.brand;
      _modelController.text = vehicle.model;
      _colorController.text = vehicle.color;
      _plateController.text = vehicle.plate;
      _localPhotoUrl = vehicle.photoUrl;
      _localLicensePhotoUrl = vehicle.licensePhotoUrl;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditMode ? 'Fotos del vehículo' : 'Registrar vehículo'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isEditMode) ...[
                Text(
                  'Solo puedes actualizar las fotos. Marca, modelo, color y '
                  'placa no se modifican. Cambiar fotos no pide nueva verificación.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _photoPicker(
                    label: 'Foto del vehículo',
                    isLicense: false,
                    file: _pickedPhotoFile,
                    networkUrl: _localPhotoUrl,
                  ),
                  const SizedBox(width: 16),
                  _photoPicker(
                    label: 'Foto de licencia',
                    isLicense: true,
                    file: _pickedLicensePhotoFile,
                    networkUrl: _localLicensePhotoUrl,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _brandController,
                readOnly: isEditMode,
                decoration: _decoration(
                  prefixIcon: Icons.directions_car_outlined,
                  labelText: 'Marca (ej: Toyota)',
                  readOnly: isEditMode,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                readOnly: isEditMode,
                decoration: _decoration(
                  prefixIcon: Icons.build_outlined,
                  labelText: 'Modelo (ej: Corolla)',
                  readOnly: isEditMode,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                readOnly: isEditMode,
                decoration: _decoration(
                  prefixIcon: Icons.color_lens_outlined,
                  labelText: 'Color (ej: Blanco)',
                  readOnly: isEditMode,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                readOnly: isEditMode,
                decoration: _decoration(
                  prefixIcon: Icons.pin_outlined,
                  labelText: 'Placa (ej: ABC-1234)',
                  readOnly: isEditMode,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: AppStrings.save,
                isLoading: notifierState.isLoading,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  if (isEditMode) {
                    if (_pickedPhotoFile == null &&
                        _pickedLicensePhotoFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Selecciona al menos una foto nueva para actualizar.',
                          ),
                        ),
                      );
                      return;
                    }

                    final repository = ref.read(vehicleRepositoryProvider);
                    final fields = <String, dynamic>{};
                    if (_pickedPhotoFile != null) {
                      final previous =
                          _localPhotoUrl ?? vehicle.photoUrl;
                      if (previous != null) {
                        await CachedNetworkImage.evictFromCache(previous);
                      }
                      fields['photo_url'] =
                          await repository.uploadVehiclePhoto(
                        vehicle.id,
                        _pickedPhotoFile!,
                        previousUrl: previous,
                        ownerUserId: userId,
                      );
                    }
                    if (_pickedLicensePhotoFile != null) {
                      final previous =
                          _localLicensePhotoUrl ?? vehicle.licensePhotoUrl;
                      if (previous != null) {
                        await CachedNetworkImage.evictFromCache(previous);
                      }
                      fields['license_photo_url'] =
                          await repository.uploadLicensePhoto(
                        vehicle.id,
                        _pickedLicensePhotoFile!,
                        previousUrl: previous,
                        ownerUserId: userId,
                      );
                    }
                    // No approval_status: keep current verification.
                    await ref
                        .read(vehicleNotifierProvider.notifier)
                        .updateVehicle(vehicle.id, userId, fields);
                  } else {
                    if (_pickedPhotoFile == null ||
                        _pickedLicensePhotoFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Agrega la foto del vehículo y de la licencia.',
                          ),
                        ),
                      );
                      return;
                    }
                    await ref
                        .read(vehicleNotifierProvider.notifier)
                        .createVehicleWithPhotos(
                          userId,
                          _brandController.text.trim(),
                          _modelController.text.trim(),
                          _colorController.text.trim(),
                          _plateController.text.trim(),
                          _pickedPhotoFile!,
                          _pickedLicensePhotoFile!,
                        );
                  }

                  final result = ref.read(vehicleNotifierProvider);
                  if (!context.mounted) return;
                  if (result.hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.error.toString())),
                    );
                    return;
                  }

                  if (isEditMode) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fotos actualizadas'),
                      ),
                    );
                    context.pop();
                  } else {
                    ref.invalidate(onboardingStatusProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vehículo registrado. La aprobación está pendiente.',
                        ),
                      ),
                    );
                    context.go(AppStrings.routeOnboardingVehiclePending);
                  }
                },
              ),
              if (isEditMode) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar vehículo'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: notifierState.isLoading
                      ? null
                      : () => _deleteVehicle(vehicle.id, userId),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
