import 'package:equatable/equatable.dart';

/// Entity representing a vehicle registered by a driver.
class Vehicle extends Equatable {
  final String id;
  final String driverId;
  final String brand;
  final String model;
  final String color;
  final String plate;
  final String? photoUrl;

  const Vehicle({
    required this.id,
    required this.driverId,
    required this.brand,
    required this.model,
    required this.color,
    required this.plate,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [
    id,
    driverId,
    brand,
    model,
    color,
    plate,
    photoUrl,
  ];
}
