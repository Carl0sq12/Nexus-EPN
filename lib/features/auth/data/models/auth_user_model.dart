import '../../domain/entities/auth_user.dart';

/// Modelo de datos para `AuthUser` con serialización desde/hacia JSON
/// usando las columnas de Supabase en snake_case.
class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required String id,
    required String email,
    String? fullName,
    required String role,
    String? avatarUrl,
    DateTime? createdAt,
  }) : super(
         id: id,
         email: email,
         fullName: fullName,
         role: role,
         avatarUrl: avatarUrl,
         createdAt: createdAt,
       );

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'passenger',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
