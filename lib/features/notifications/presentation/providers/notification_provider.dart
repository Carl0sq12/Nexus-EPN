import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/appwrite_provider.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../domain/entities/app_notification.dart';

final notificationRemoteDatasourceProvider =
    Provider<NotificationRemoteDatasource>((ref) {
  return NotificationRemoteDatasource(
    databases: ref.watch(databasesProvider),
  );
});

final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) async* {
  final ds = ref.watch(notificationRemoteDatasourceProvider);
  while (true) {
    try {
      yield await ds.listForUser(userId);
    } catch (_) {}
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});
