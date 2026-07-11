import 'package:equatable/equatable.dart';

/// Entity representing a user profile in the application.
class Profile extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? cedula;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.cedula,
  });

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        role,
        avatarUrl,
        phone,
        cedula,
      ];
}
