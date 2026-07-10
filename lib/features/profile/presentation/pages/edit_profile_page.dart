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
  String? _localAvatarUrl;
  File? _pickedImageFile;
  bool _initialized = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  String _getInitials(String fullName) {
    return fullName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null && mounted) {
      setState(() => _pickedImageFile = File(result.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;

    if (userId == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final profileAsync = ref.watch(profileProvider(userId));
    final notifierState = ref.watch(profileNotifierProvider);

    ref.listen(profileNotifierProvider, (previous, next) {
      if (next is AsyncError && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      } else if (next is AsyncData && mounted) {
        context.pop();
      }
    });

    final profile = profileAsync.asData?.value;
    if (profile != null && !_initialized) {
      _initialized = true;
      _fullNameController.text = profile.fullName;
      _localAvatarUrl = profile.avatarUrl;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar perfil'),
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
                onTap: _pickImage,
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
                      child:
                          _pickedImageFile == null &&
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
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.onPrimary,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.primarySoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.secondary,
                  ),
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
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.outlineVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.secondary,
                  ),
                  suffixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppColors.secondary,
                  ),
                  labelText: AppStrings.emailLabel,
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: AppStrings.save,
                isLoading: notifierState.isLoading,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  String? avatarUrl = _localAvatarUrl;
                  if (_pickedImageFile != null) {
                    final datasource = ref.read(profileDatasourceProvider);
                    avatarUrl = await datasource.uploadAvatar(
                      userId,
                      _pickedImageFile!,
                    );
                  }

                  if (!mounted) return;
                  ref
                      .read(profileNotifierProvider.notifier)
                      .updateProfile(
                        userId,
                        _fullNameController.text.trim(),
                        avatarUrl,
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
