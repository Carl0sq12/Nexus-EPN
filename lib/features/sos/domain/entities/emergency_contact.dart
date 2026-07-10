class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? relationship;
  final DateTime createdAt;

  const EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.relationship,
    required this.createdAt,
  });
}
