import '../../domain/entities/profile.dart';

/// Data model for [Profile] with JSON serialization using Supabase snake_case keys.
class ProfileModel extends Profile {
  const ProfileModel({
    required String id,
    required String fullName,
    required String email,
    required String role,
    String? avatarUrl,
  }) : super(
         id: id,
         fullName: fullName,
         email: email,
         role: role,
         avatarUrl: avatarUrl,
       );

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String,
      role: json['role'] as String? ?? 'passenger',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'email': email,
      'role': role,
      'avatar_url': avatarUrl,
    };
  }
}
