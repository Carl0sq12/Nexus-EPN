import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../providers/auth_provider.dart';

/// Mandatory screen when Supabase reports an unverified email.
class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final email = client.auth.currentUser?.email ?? 'tu correo institucional';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verifica tu correo',
                style: AppTextStyles.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Enviamos un enlace de verificación a $email. Debes confirmarlo antes de continuar.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Ya verifiqué',
                onPressed: () async {
                  await client.auth.refreshSession();
                  ref.invalidate(onboardingStatusProvider);
                  if (context.mounted) context.go(AppStrings.routeSplash);
                },
              ),
              const SizedBox(height: 12),
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
