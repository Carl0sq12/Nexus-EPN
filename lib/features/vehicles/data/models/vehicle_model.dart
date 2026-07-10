import '../../domain/entities/vehicle.dart';

/// Data model for [Vehicle] with JSON serialization using Supabase snake_case keys.
class VehicleModel extends Vehicle {
  const VehicleModel({
    required String id,
    required String driverId,
    required String brand,
    required String model,
    required String color,
    required String plate,
    String? photoUrl,
  }) : super(
         id: id,
         driverId: driverId,
         brand: brand,
         model: model,
         color: color,
         plate: plate,
         photoUrl: photoUrl,
       );

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String? ?? '',
      plate: json['plate'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
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
    };
  }
}
