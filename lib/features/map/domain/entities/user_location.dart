import 'package:equatable/equatable.dart';

/// Entity representing a geographical location (latitude & longitude).
class UserLocation extends Equatable {
  final double latitude;
  final double longitude;

  const UserLocation({required this.latitude, required this.longitude});

  @override
  List<Object?> get props => [latitude, longitude];
}
