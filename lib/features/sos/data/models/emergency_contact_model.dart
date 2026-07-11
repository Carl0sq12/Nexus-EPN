import '../../domain/entities/emergency_contact.dart';

class EmergencyContactModel extends EmergencyContact {
  const EmergencyContactModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.phone,
    super.relationship,
    required super.createdAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] ?? json[r'$createdAt'];
    return EmergencyContactModel(
      id: (json['id'] ?? json[r'$id']) as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
      createdAt: DateTime.parse(createdRaw as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'phone': phone,
    'relationship': relationship,
    'created_at': createdAt.toIso8601String(),
  };
}
