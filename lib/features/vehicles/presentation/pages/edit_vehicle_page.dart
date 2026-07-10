import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/vehicle_provider.dart';

/// Create or edit vehicle page with photo upload and form fields.
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
  File? _pickedPhotoFile;
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
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null && mounted) {
      setState(() => _pickedPhotoFile = File(result.path));
    }
  }

  InputDecoration _decoration({
    required IconData prefixIcon,
    required String labelText,
    bool readOnly = false,
    Widget? suffixIcon,
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
      suffixIcon: suffixIcon,
      labelText: labelText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;

    if (userId == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final vehicleAsync = ref.watch(myVehicleProvider(userId));
    final vehicle = vehicleAsync.asData?.value;
    final isEditMode = vehicle != null;
    final notifierState = ref.watch(vehicleNotifierProvider);

    ref.listen(vehicleNotifierProvider, (previous, next) {
      if (next is AsyncError && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      } else if (next is AsyncData && mounted) {
        context.pop();
      }
    });

    if (vehicle != null && !_initialized) {
      _initialized = true;
      _brandController.text = vehicle.brand;
      _modelController.text = vehicle.model;
      _colorController.text = vehicle.color;
      _plateController.text = vehicle.plate;
      _localPhotoUrl = vehicle.photoUrl;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditMode ? 'Editar vehículo' : 'Registrar vehículo'),
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
            children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.primarySoft,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _pickedPhotoFile != null
                          ? Image.file(_pickedPhotoFile!, fit: BoxFit.cover)
                          : _localPhotoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _localPhotoUrl!,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '  Toca para cambiar',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _brandController,
                decoration: _decoration(
                  prefixIcon: Icons.directions_car_outlined,
                  labelText: 'Marca (ej: Toyota)',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: _decoration(
                  prefixIcon: Icons.build_outlined,
                  labelText: 'Modelo (ej: Corolla)',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: _decoration(
                  prefixIcon: Icons.color_lens_outlined,
                  labelText: 'Color (ej: Blanco)',
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
                  suffixIcon: isEditMode
                      ? const Icon(
                          Icons.lock_outline,
                          color: AppColors.secondary,
                        )
                      : null,
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

                  String? photoUrl = _localPhotoUrl;
                  if (_pickedPhotoFile != null) {
                    final datasource = ref.read(vehicleDatasourceProvider);
                    photoUrl = await datasource.uploadVehiclePhoto(
                      isEditMode ? vehicle.id : 'temp',
                      _pickedPhotoFile!,
                    );
                  }

                  if (!mounted) return;

                  if (isEditMode) {
                    final fields = <String, dynamic>{
                      'brand': _brandController.text.trim(),
                      'model': _modelController.text.trim(),
                      'color': _colorController.text.trim(),
                    };
                    if (photoUrl != null && photoUrl != vehicle.photoUrl) {
                      fields['photo_url'] = photoUrl;
                    }
                    ref
                        .read(vehicleNotifierProvider.notifier)
                        .updateVehicle(vehicle.id, userId, fields);
                  } else {
                    await ref
                        .read(vehicleNotifierProvider.notifier)
                        .createVehicle(
                          userId,
                          _brandController.text.trim(),
                          _modelController.text.trim(),
                          _colorController.text.trim(),
                          _plateController.text.trim(),
                        );
                    if (photoUrl != null && mounted) {
                      final newVehicleAsync = ref.read(
                        myVehicleProvider(userId),
                      );
                      final newVehicle = newVehicleAsync.asData?.value;
                      if (newVehicle != null) {
                        ref
                            .read(vehicleNotifierProvider.notifier)
                            .updateVehicle(newVehicle.id, userId, {
                              'photo_url': photoUrl,
                            });
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
