import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
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
          context.go(_routeForStep(status.step));
        });
      },
      loading: () {},
      error: (e, st) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(AppStrings.routeLogin);
        });
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(13, 111, 148, 0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.route, color: Colors.white, size: 40),
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
    case OnboardingStep.registerContacts:
      return AppStrings.routeOnboardingContacts;
    case OnboardingStep.home:
      return AppStrings.routeHome;
  }
}
