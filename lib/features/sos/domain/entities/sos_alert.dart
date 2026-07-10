import 'package:equatable/equatable.dart';

/// Entity representing an SOS emergency alert.
class SosAlert extends Equatable {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final String message;
  final String type;
  final DateTime createdAt;

  const SosAlert({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    latitude,
    longitude,
    message,
    type,
    createdAt,
  ];
}
