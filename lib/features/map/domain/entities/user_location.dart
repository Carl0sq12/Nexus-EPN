import 'package:equatable/equatable.dart';

/// Entity representing a geographical location (latitude & longitude).
class UserLocation extends Equatable {
  final double latitude;
  final double longitude;
  final double heading;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.heading = 0,
  });

  @override
  List<Object?> get props => [latitude, longitude, heading];
}
