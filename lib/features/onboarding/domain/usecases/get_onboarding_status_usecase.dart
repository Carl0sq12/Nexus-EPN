import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../sos/domain/repositories/emergency_contacts_repository.dart';
import '../../../vehicles/domain/repositories/vehicle_repository.dart';
import '../entities/onboarding_status.dart';

/// Evaluates the mandatory onboarding rules before a user can enter Home.
class GetOnboardingStatusUseCase {
  final SupabaseClient supabaseClient;
  final ProfileRepository profileRepository;
  final VehicleRepository vehicleRepository;
  final EmergencyContactsRepositoryContract emergencyContactsRepository;

  const GetOnboardingStatusUseCase({
    required this.supabaseClient,
    required this.profileRepository,
    required this.vehicleRepository,
    required this.emergencyContactsRepository,
  });

  Future<OnboardingStatus> call() async {
    // Rule 2: Splash/guards start by checking if a valid Supabase session exists.
    final session = supabaseClient.auth.currentSession;
    final user = session?.user;
    if (user == null) return const OnboardingStatus.unauthenticated();

    // Rule 2/9: verified email is mandatory before Home.
    final hasVerifiedEmail = user.emailConfirmedAt != null;
    if (!hasVerifiedEmail) {
      return OnboardingStatus(
        step: OnboardingStep.verifyEmail,
        userId: user.id,
        role: null,
        hasVerifiedEmail: false,
        hasCompleteProfile: false,
        hasVehicle: false,
        emergencyContactsCount: 0,
      );
    }

    final profile = await profileRepository.getProfile(user.id);
    final role = profile.role;

    // Rule 2/9: profile is complete only when basic identity and role exist.
    final hasCompleteProfile =
        profile.fullName.trim().isNotEmpty &&
        profile.email.trim().isNotEmpty &&
        (role == 'passenger' || role == 'driver');
    if (!hasCompleteProfile) {
      return OnboardingStatus(
        step: OnboardingStep.completeProfile,
        userId: user.id,
        role: role,
        hasVerifiedEmail: true,
        hasCompleteProfile: false,
        hasVehicle: false,
        emergencyContactsCount: 0,
      );
    }

    var hasVehicle = true;
    if (role == 'driver') {
      // Rule 7/8/9: drivers cannot access Home or driver features without a vehicle.
      final vehicle = await vehicleRepository.getMyVehicle(user.id);
      hasVehicle = vehicle != null && vehicle.photoUrl != null;
      if (!hasVehicle) {
        return OnboardingStatus(
          step: OnboardingStep.registerVehicle,
          userId: user.id,
          role: role,
          hasVerifiedEmail: true,
          hasCompleteProfile: true,
          hasVehicle: false,
          emergencyContactsCount: 0,
        );
      }
    }

    final contacts = await emergencyContactsRepository.getContacts(user.id);
    final emergencyContactsCount = contacts.length;
    if (emergencyContactsCount < 2) {
      // Rule 7/9: every user must have at least two emergency contacts.
      return OnboardingStatus(
        step: OnboardingStep.registerContacts,
        userId: user.id,
        role: role,
        hasVerifiedEmail: true,
        hasCompleteProfile: true,
        hasVehicle: hasVehicle,
        emergencyContactsCount: emergencyContactsCount,
      );
    }

    return OnboardingStatus(
      step: OnboardingStep.home,
      userId: user.id,
      role: role,
      hasVerifiedEmail: true,
      hasCompleteProfile: true,
      hasVehicle: hasVehicle,
      emergencyContactsCount: emergencyContactsCount,
    );
  }
}
