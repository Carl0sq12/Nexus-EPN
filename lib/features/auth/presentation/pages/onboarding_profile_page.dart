import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Mandatory profile completion screen before Home.
class OnboardingProfilePage extends ConsumerStatefulWidget {
  const OnboardingProfilePage({super.key});

  @override
  ConsumerState<OnboardingProfilePage> createState() =>
      _OnboardingProfilePageState();
}

class _OnboardingProfilePageState extends ConsumerState<OnboardingProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).value?.session?.user.id;
    final notifierState = ref.watch(profileNotifierProvider);

    if (userId == null) return const Scaffold(body: SizedBox.shrink());

    final profileAsync = ref.watch(profileProvider(userId));
    final profile = profileAsync.asData?.value;
    if (profile != null && !_initialized) {
      _initialized = true;
      _fullNameController.text = profile.fullName;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Completar perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Datos básicos', style: AppTextStyles.displayLarge),
              const SizedBox(height: 8),
              Text(
                'Completa tu nombre para continuar a Nexus Campus.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  labelText: 'Nombre completo',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: AppStrings.save,
                isLoading: notifierState.isLoading,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  await ref
                      .read(profileNotifierProvider.notifier)
                      .updateProfile(
                        userId,
                        _fullNameController.text.trim(),
                        profile?.avatarUrl,
                      );
                  ref.invalidate(onboardingStatusProvider);
                  if (context.mounted) context.go(AppStrings.routeSplash);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
