import '../../domain/entities/sos_alert.dart';

/// Data model for [SosAlert] with JSON serialization using Supabase snake_case keys.
class SosAlertModel extends SosAlert {
  const SosAlertModel({
    required String id,
    required String userId,
    required double latitude,
    required double longitude,
    required String message,
    required String type,
    required DateTime createdAt,
  }) : super(
         id: id,
         userId: userId,
         latitude: latitude,
         longitude: longitude,
         message: message,
         type: type,
         createdAt: createdAt,
       );

  factory SosAlertModel.fromJson(Map<String, dynamic> json) {
    return SosAlertModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'personal_emergency',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'type': type,
    };
  }
}
