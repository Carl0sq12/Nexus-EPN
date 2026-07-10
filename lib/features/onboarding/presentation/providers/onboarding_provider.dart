import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/providers/session_data_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../sos/presentation/providers/emergency_contacts_provider.dart';
import '../../../vehicles/presentation/providers/vehicle_provider.dart';
import '../../domain/entities/onboarding_status.dart';
import '../../domain/usecases/get_onboarding_status_usecase.dart';

final getOnboardingStatusUseCaseProvider = Provider<GetOnboardingStatusUseCase>(
  (ref) {
    return GetOnboardingStatusUseCase(
      supabaseClient: ref.watch(supabaseClientProvider),
      profileRepository: ref.watch(profileRepositoryProvider),
      vehicleRepository: ref.watch(vehicleRepositoryProvider),
      emergencyContactsRepository: ref.watch(
        emergencyContactsRepositoryProvider,
      ),
    );
  },
);

/// Central provider used by Splash and GoRouter guards.
///
/// Business rules implemented by [GetOnboardingStatusUseCase]:
/// session, verified email, profile completeness, role, driver vehicle and
/// minimum emergency contacts.
final onboardingStatusProvider = FutureProvider<OnboardingStatus>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(sessionDataVersionProvider);
  return ref.watch(getOnboardingStatusUseCaseProvider)();
});

final driverCanUseDriverFeaturesProvider = Provider<bool>((ref) {
  final status = ref.watch(onboardingStatusProvider).asData?.value;
  return status?.role == 'driver' && status?.hasVehicle == true;
});
