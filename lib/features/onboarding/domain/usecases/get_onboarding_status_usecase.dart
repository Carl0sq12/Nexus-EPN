import 'package:appwrite/appwrite.dart';

import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../sos/domain/repositories/emergency_contacts_repository.dart';
import '../../../vehicles/domain/repositories/vehicle_repository.dart';
import '../entities/onboarding_status.dart';

/// Evaluates the mandatory onboarding rules before a user can enter Home.
class GetOnboardingStatusUseCase {
  final Account account;
  final ProfileRepository profileRepository;
  final VehicleRepository vehicleRepository;
  final EmergencyContactsRepositoryContract emergencyContactsRepository;

  const GetOnboardingStatusUseCase({
    required this.account,
    required this.profileRepository,
    required this.vehicleRepository,
    required this.emergencyContactsRepository,
  });

  Future<OnboardingStatus> call() async {
    late final String userId;
    late final bool hasVerifiedEmail;

    try {
      final user = await account.get();
      userId = user.$id;
      hasVerifiedEmail = user.emailVerification;
    } on AppwriteException {
      return const OnboardingStatus.unauthenticated();
    } catch (_) {
      return const OnboardingStatus.unauthenticated();
    }

    if (!hasVerifiedEmail) {
      return OnboardingStatus(
        step: OnboardingStep.verifyEmail,
        userId: userId,
        role: null,
        hasVerifiedEmail: false,
        hasCompleteProfile: false,
        hasVehicle: false,
        emergencyContactsCount: 0,
      );
    }

    String? role;
    var hasCompleteProfile = false;
    try {
      final profile = await profileRepository.getProfile(userId);
      role = profile.role;
      hasCompleteProfile =
          profile.fullName.trim().isNotEmpty &&
          profile.email.trim().isNotEmpty &&
          (role == 'passenger' || role == 'driver');
    } catch (_) {
      hasCompleteProfile = false;
    }

    if (!hasCompleteProfile) {
      return OnboardingStatus(
        step: OnboardingStep.completeProfile,
        userId: userId,
        role: role,
        hasVerifiedEmail: true,
        hasCompleteProfile: false,
        hasVehicle: false,
        emergencyContactsCount: 0,
      );
    }

    var hasVehicle = true;
    var isVehicleApproved = true;
    if (role == 'driver') {
      try {
        final vehicle = await vehicleRepository.getMyVehicle(userId);
        hasVehicle =
            vehicle != null &&
            (vehicle.photoUrl?.isNotEmpty ?? false) &&
            (vehicle.licensePhotoUrl?.isNotEmpty ?? false);
        isVehicleApproved = vehicle?.isApproved ?? false;
      } catch (_) {
        hasVehicle = false;
        isVehicleApproved = false;
      }
      if (!hasVehicle) {
        return OnboardingStatus(
          step: OnboardingStep.registerVehicle,
          userId: userId,
          role: role,
          hasVerifiedEmail: true,
          hasCompleteProfile: true,
          hasVehicle: false,
          isVehicleApproved: false,
          emergencyContactsCount: 0,
        );
      }
      if (!isVehicleApproved) {
        return OnboardingStatus(
          step: OnboardingStep.vehiclePending,
          userId: userId,
          role: role,
          hasVerifiedEmail: true,
          hasCompleteProfile: true,
          hasVehicle: true,
          isVehicleApproved: false,
          emergencyContactsCount: 0,
        );
      }
    }

    var emergencyContactsCount = 0;
    try {
      final contacts = await emergencyContactsRepository.getContacts(userId);
      emergencyContactsCount = contacts.length;
    } catch (_) {
      emergencyContactsCount = 0;
    }

    if (emergencyContactsCount < 2) {
      return OnboardingStatus(
        step: OnboardingStep.registerContacts,
        userId: userId,
        role: role,
        hasVerifiedEmail: true,
        hasCompleteProfile: true,
        hasVehicle: hasVehicle,
        isVehicleApproved: isVehicleApproved,
        emergencyContactsCount: emergencyContactsCount,
      );
    }

    return OnboardingStatus(
      step: OnboardingStep.home,
      userId: userId,
      role: role,
      hasVerifiedEmail: true,
      hasCompleteProfile: true,
      hasVehicle: hasVehicle,
      isVehicleApproved: isVehicleApproved,
      emergencyContactsCount: emergencyContactsCount,
    );
  }
}
