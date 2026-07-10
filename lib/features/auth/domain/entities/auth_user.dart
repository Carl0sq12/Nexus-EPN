import 'package:equatable/equatable.dart';

/// Entidad que representa un usuario autenticado en la aplicación.
class AuthUser extends Equatable {
  final String id;
  final String email;
  final String? fullName;
  final String role;
  final String? avatarUrl;
  final DateTime? createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, email, fullName, role, avatarUrl, createdAt];
}
