import 'package:equatable/equatable.dart';

/// Approval lifecycle for a driver vehicle.
abstract final class VehicleApprovalStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

/// Entity representing a vehicle registered by a driver.
class Vehicle extends Equatable {
  final String id;
  final String driverId;
  final String brand;
  final String model;
  final String color;
  final String plate;
  final String? photoUrl;
  final String? licensePhotoUrl;
  final String approvalStatus;

  const Vehicle({
    required this.id,
    required this.driverId,
    required this.brand,
    required this.model,
    required this.color,
    required this.plate,
    this.photoUrl,
    this.licensePhotoUrl,
    this.approvalStatus = VehicleApprovalStatus.pending,
  });

  bool get isApproved => approvalStatus == VehicleApprovalStatus.approved;
  bool get isPending => approvalStatus == VehicleApprovalStatus.pending;
  bool get isRejected => approvalStatus == VehicleApprovalStatus.rejected;

  @override
  List<Object?> get props => [
    id,
    driverId,
    brand,
    model,
    color,
    plate,
    photoUrl,
    licensePhotoUrl,
    approvalStatus,
  ];
}
