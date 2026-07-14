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

/// Seat/cupo request events belong in Solicitudes, not in Notificaciones.
const seatRequestNotificationTypes = {
  'trip_request',
  'request_accepted',
  'request_rejected',
  'price_proposed',
  'price_accepted',
  'request_cancelled',
};

bool isSeatRequestNotification(String type) =>
    seatRequestNotificationTypes.contains(type);

final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) async* {
  final ds = ref.watch(notificationRemoteDatasourceProvider);
  while (true) {
    try {
      final all = await ds.listForUser(userId);
      // Chat, trip finished/cancelled, SOS, etc. — never seat requests.
      yield all.where((n) => !isSeatRequestNotification(n.type)).toList();
    } catch (_) {}
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});
