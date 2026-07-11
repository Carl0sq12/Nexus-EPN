import '../../domain/entities/app_notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.body,
    required super.type,
    required super.read,
    required super.createdAt,
    super.relatedId,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: (json['id'] ?? json[r'$id']) as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      read: json['read'] as bool? ?? false,
      relatedId: json['related_id'] as String?,
      createdAt: DateTime.tryParse(
            (json['created_at'] ?? json[r'$createdAt'] ?? '') as String,
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': read,
        'related_id': relatedId,
      };
}
