import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/domain/entities/onboarding_status.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

/// Splash page with Coastal Wave branding that checks auth and redirects.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingStatusProvider);

    onboardingState.when(
      data: (status) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.go(_routeForStep(status.step));
        });
      },
      loading: () {},
      error: (_, __) {},
    );

    final hasError = onboardingState.hasError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.appName, style: AppTextStyles.displayLarge),
            const SizedBox(height: 8),
            Text(
              AppStrings.appTagline,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            if (hasError) ...[
              Text(
                'No se pudo cargar tu sesión.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Reintentar',
                onPressed: () => ref.invalidate(onboardingStatusProvider),
              ),
              const SizedBox(height: 8),
              CustomButton(
                label: 'Ir al login',
                isOutlined: true,
                onPressed: () => context.go(AppStrings.routeLogin),
              ),
            ] else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
          ],
        ),
      ),
    );
  }
}

String _routeForStep(OnboardingStep step) {
  switch (step) {
    case OnboardingStep.unauthenticated:
      return AppStrings.routeLogin;
    case OnboardingStep.verifyEmail:
      return AppStrings.routeVerifyEmail;
    case OnboardingStep.completeProfile:
      return AppStrings.routeOnboardingProfile;
    case OnboardingStep.registerVehicle:
      return AppStrings.routeOnboardingVehicle;
    case OnboardingStep.vehiclePending:
      return AppStrings.routeOnboardingVehiclePending;
    case OnboardingStep.registerContacts:
      return AppStrings.routeOnboardingContacts;
    case OnboardingStep.home:
      return AppStrings.routeHome;
  }
}
