import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final String? relatedId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    this.relatedId,
  });

  @override
  List<Object?> get props =>
      [id, userId, title, body, type, read, relatedId, createdAt];
}
