import '../../domain/entities/profile.dart';

/// Data model for [Profile] with JSON serialization using snake_case keys.
class ProfileModel extends Profile {
  const ProfileModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.role,
    super.avatarUrl,
    super.phone,
    super.cedula,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: (json['id'] ?? json[r'$id']) as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'passenger',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      cedula: json['cedula'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'email': email,
      'role': role,
      'avatar_url': avatarUrl,
      'phone': phone,
      'cedula': cedula,
    };
  }
}
