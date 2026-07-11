import '../../domain/entities/vehicle.dart';

/// Data model for [Vehicle] with JSON serialization (Appwrite snake_case).
class VehicleModel extends Vehicle {
  const VehicleModel({
    required String id,
    required String driverId,
    required String brand,
    required String model,
    required String color,
    required String plate,
    String? photoUrl,
    String? licensePhotoUrl,
    String approvalStatus = VehicleApprovalStatus.pending,
  }) : super(
         id: id,
         driverId: driverId,
         brand: brand,
         model: model,
         color: color,
         plate: plate,
         photoUrl: photoUrl,
         licensePhotoUrl: licensePhotoUrl,
         approvalStatus: approvalStatus,
       );

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['approval_status'] as String?;
    return VehicleModel(
      id: (json['id'] ?? json[r'$id']) as String,
      driverId: json['driver_id'] as String,
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String? ?? '',
      plate: json['plate'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      licensePhotoUrl: json['license_photo_url'] as String?,
      approvalStatus: rawStatus == null || rawStatus.isEmpty
          ? VehicleApprovalStatus.pending
          : rawStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'brand': brand,
      'model': model,
      'color': color,
      'plate': plate,
      'photo_url': photoUrl,
      'license_photo_url': licensePhotoUrl,
      'approval_status': approvalStatus,
    };
  }
}
