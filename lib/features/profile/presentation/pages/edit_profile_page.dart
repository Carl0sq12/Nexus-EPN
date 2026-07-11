import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/utils/image_sharpness.dart';
import '../../../../core/utils/phone_normalizer.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicle_provider.dart';
import '../providers/profile_provider.dart';

/// Edit profile page with avatar upload and name update.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cedulaController = TextEditingController();
  String? _localAvatarUrl;
  String? _localLicensePhotoUrl;
  File? _pickedImageFile;
  File? _pickedLicensePhotoFile;
  bool _initialized = false;
  bool _vehicleInitialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cedulaController.dispose();
    super.dispose();
  }

  String _getInitials(String fullName) {
    return fullName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  InputDecoration _fieldDecoration({
    required IconData prefixIcon,
    required String labelText,
    Widget? suffixIcon,
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
      suffixIcon: suffixIcon,
      labelText: labelText,
      counterText: '',
    );
  }

  Future<void> _pickAvatar() async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(source: source, imageQuality: 85);
    if (result != null && mounted) {
      setState(() => _pickedImageFile = File(result.path));
    }
  }

  Future<void> _pickLicensePhoto() async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(source: source, imageQuality: 85);
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
    setState(() => _pickedLicensePhotoFile = file);
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String userId, Vehicle? vehicle, bool isDriver) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      // Vehicle/license first so a storage failure doesn't look like a full save.
      if (vehicle != null && _pickedLicensePhotoFile != null) {
        final previousUrl = _localLicensePhotoUrl ?? vehicle.licensePhotoUrl;
        if (previousUrl != null) {
          await CachedNetworkImage.evictFromCache(previousUrl);
        }
        final newUrl = await ref.read(vehicleRepositoryProvider).uploadLicensePhoto(
              vehicle.id,
              _pickedLicensePhotoFile!,
              previousUrl: previousUrl,
              ownerUserId: userId,
            );
        // Photo-only update: keep current approval / verification status.
        await ref.read(vehicleNotifierProvider.notifier).updateVehicle(
              vehicle.id,
              userId,
              {'license_photo_url': newUrl},
            );
        final vehicleResult = ref.read(vehicleNotifierProvider);
        if (vehicleResult.hasError) {
          throw vehicleResult.error!;
        }
        _localLicensePhotoUrl = newUrl;
        _pickedLicensePhotoFile = null;
      }

      String? avatarUrl = _localAvatarUrl;
      if (_pickedImageFile != null) {
        final datasource = ref.read(profileDatasourceProvider);
        avatarUrl = await datasource.uploadAvatar(userId, _pickedImageFile!);
      }

      await ref.read(profileNotifierProvider.notifier).updateProfile(
            userId,
            fullName: _fullNameController.text.trim(),
            avatarUrl: avatarUrl,
            phone: PhoneNormalizer.forStorage(_phoneController.text.trim()),
            cedula: isDriver ? _cedulaController.text.trim() : null,
          );
      final profileResult = ref.read(profileNotifierProvider);
      if (profileResult.hasError) {
        throw profileResult.error!;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información actualizada')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;

    if (userId == null) {
      return const Scaffold(body: AppLoadingView());
    }

    final profileAsync = ref.watch(profileProvider(userId));
    final profile = profileAsync.asData?.value;
    final isDriver = profile?.role == AppStrings.roleDriver;
    final vehicleAsync =
        isDriver ? ref.watch(myVehicleProvider(userId)) : null;
    final vehicle = vehicleAsync?.asData?.value;

    if (profile != null && !_initialized) {
      _initialized = true;
      _fullNameController.text = profile.fullName;
      _phoneController.text = profile.phone ?? '';
      _cedulaController.text = profile.cedula ?? '';
      _localAvatarUrl = profile.avatarUrl;
    }
    if (vehicle != null && !_vehicleInitialized) {
      _vehicleInitialized = true;
      _localLicensePhotoUrl = vehicle.licensePhotoUrl;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Información personal'),
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
          // Evita que Android Autofill inyecte un campo de contraseña.
          autovalidateMode: AutovalidateMode.disabled,
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: _pickedImageFile != null
                            ? FileImage(_pickedImageFile!)
                            : (_localAvatarUrl != null
                                ? CachedNetworkImageProvider(_localAvatarUrl!)
                                : null),
                        backgroundColor: AppColors.primarySoft,
                        child: _pickedImageFile == null &&
                                _localAvatarUrl == null &&
                                profile != null
                            ? Text(
                                _getInitials(profile.fullName),
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.camera_alt,
                            color: AppColors.onPrimary,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toca la cámara para cambiar tu foto',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _fullNameController,
                  autofillHints: const [],
                  enableSuggestions: false,
                  decoration: _fieldDecoration(
                    prefixIcon: Icons.person_outline,
                    labelText: 'Nombre completo',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo requerido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  initialValue: profile?.email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  enableInteractiveSelection: false,
                  decoration: _fieldDecoration(
                    prefixIcon: Icons.email_outlined,
                    labelText: 'Correo institucional',
                    readOnly: true,
                    suffixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  decoration: _fieldDecoration(
                    prefixIcon: Icons.phone_outlined,
                    labelText: 'Número celular',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Campo requerido';
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 9) {
                      return 'Ingresa un número válido';
                    }
                    return null;
                  },
                ),
                Text(
                  'Si alguien te agrega como contacto de emergencia, recibirá el SOS en este número.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isDriver) ...[
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Mi vehículo', style: AppTextStyles.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  if (vehicleAsync?.isLoading == true)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (vehicle == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Aún no tienes un vehículo registrado.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppStrings.routeVehicleEdit),
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar vehículo'),
                        ),
                      ],
                    )
                  else ...[
                    _VehicleInfoCard(vehicle: vehicle),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Foto de licencia',
                        style: AppTextStyles.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Puedes actualizarla sin nueva verificación.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickLicensePhoto,
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.primarySoft,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _pickedLicensePhotoFile != null
                            ? Image.file(
                                _pickedLicensePhotoFile!,
                                fit: BoxFit.cover,
                              )
                            : _localLicensePhotoUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: _localLicensePhotoUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.badge_outlined,
                                          size: 36,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(height: 6),
                                        Text('Subir foto de licencia'),
                                      ],
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cedulaController,
                      keyboardType: TextInputType.number,
                      autofillHints: const [],
                      enableSuggestions: false,
                      obscureText: false,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: _fieldDecoration(
                        prefixIcon: Icons.badge_outlined,
                        labelText: 'Cédula de identidad',
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Campo requerido';
                        if (value.length != 10) {
                          return 'La cédula debe tener 10 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          context.push(AppStrings.routeVehicleEdit),
                      child: const Text('Actualizar fotos del vehículo'),
                    ),
                  ],
                ],
                const SizedBox(height: 32),
                CustomButton(
                  label: AppStrings.save,
                  isLoading: _saving,
                  onPressed: () => _save(userId, vehicle, isDriver),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleInfoCard extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleInfoCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (vehicle.photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: vehicle.photoUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    color: AppColors.primary,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.brand} ${vehicle.model}',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Color: ${vehicle.color}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Placa: ${vehicle.plate}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel(vehicle.approvalStatus),
                      style: AppTextStyles.caption.copyWith(
                        color: vehicle.isApproved
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case VehicleApprovalStatus.approved:
        return 'Aprobado';
      case VehicleApprovalStatus.rejected:
        return 'Rechazado';
      default:
        return 'Pendiente de aprobación';
    }
  }
}
