import 'package:equatable/equatable.dart';

enum OnboardingStep {
  unauthenticated,
  verifyEmail,
  completeProfile,
  registerVehicle,
  vehiclePending,
  registerContacts,
  home,
}

/// Result of evaluating every onboarding business rule.
class OnboardingStatus extends Equatable {
  final OnboardingStep step;
  final String? userId;
  final String? role;
  final bool hasVerifiedEmail;
  final bool hasCompleteProfile;
  final bool hasVehicle;
  final bool isVehicleApproved;
  final int emergencyContactsCount;

  const OnboardingStatus({
    required this.step,
    required this.hasVerifiedEmail,
    required this.hasCompleteProfile,
    required this.hasVehicle,
    required this.emergencyContactsCount,
    this.isVehicleApproved = false,
    this.userId,
    this.role,
  });

  const OnboardingStatus.unauthenticated()
    : step = OnboardingStep.unauthenticated,
      userId = null,
      role = null,
      hasVerifiedEmail = false,
      hasCompleteProfile = false,
      hasVehicle = false,
      isVehicleApproved = false,
      emergencyContactsCount = 0;

  bool get canEnterHome => step == OnboardingStep.home;

  bool get isDriver => role == 'driver';

  @override
  List<Object?> get props => [
    step,
    userId,
    role,
    hasVerifiedEmail,
    hasCompleteProfile,
    hasVehicle,
    isVehicleApproved,
    emergencyContactsCount,
  ];
}
