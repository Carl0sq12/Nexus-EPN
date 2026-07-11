import 'package:appwrite/appwrite.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_config.dart';
import '../providers/appwrite_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';

/// Shows local notifications for new trips, chat messages, and request alerts.
class LocalNotificationService {
  LocalNotificationService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  RealtimeSubscription? _tripsSub;
  RealtimeSubscription? _notificationsSub;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  Future<bool> _pref(String key, {bool fallback = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? fallback;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      const android = AndroidNotificationDetails(
        'nexus_campus',
        'Nexus Campus',
        channelDescription: 'Viajes y chat',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: android,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Local notifications must never crash the app.
    }
  }

  Future<void> startListening(String userId) async {
    await init();
    await stopListening();

    final realtime = _ref.read(realtimeProvider);
    final ds = _ref.read(notificationRemoteDatasourceProvider);

    _tripsSub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.collectionTrips}.documents',
    ]);
    _tripsSub!.stream.listen((event) async {
      if (!await _pref('pref_trip_notifications')) return;
      if (event.events.any((e) => e.contains('.create'))) {
        const title = 'Nuevo viaje disponible';
        const body = 'Hay un nuevo viaje publicado en Nexus Campus.';
        await show(id: DateTime.now().millisecondsSinceEpoch % 100000, title: title, body: body);
        try {
          await ds.create(
            userId: userId,
            title: title,
            body: body,
            type: 'trip',
          );
          _ref.invalidate(notificationsProvider(userId));
        } catch (_) {}
      }
    });

    // Chat in-app + local alerts: sender creates notification docs for
    // trip participants; this subscription shows the device banner.
    _notificationsSub = realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.collectionNotifications}.documents',
    ]);
    _notificationsSub!.stream.listen((event) async {
      if (!event.events.any((e) => e.contains('.create'))) return;
      final payload = event.payload;
      if (payload['user_id'] != userId) return;
      final type = payload['type'] as String?;
      if (type == 'chat') {
        if (!await _pref('pref_chat_notifications')) return;
      } else if (!await _pref('pref_trip_notifications')) {
        return;
      }
      final title = (payload['title'] as String?) ?? 'Nexus Campus';
      final body = (payload['body'] as String?) ?? 'Tienes una nueva alerta';
      await show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
      );
      _ref.invalidate(notificationsProvider(userId));
    });
  }

  Future<void> stopListening() async {
    _tripsSub?.close();
    _notificationsSub?.close();
    _tripsSub = null;
    _notificationsSub = null;
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  final service = LocalNotificationService(ref);
  ref.onDispose(() {
    service.stopListening();
  });
  return service;
});

/// Keeps local notification subscriptions tied to the auth session.
final notificationListenerBootstrapProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (previous, next) {
    final userId = next.asData?.value?.userId;
    final service = ref.read(localNotificationServiceProvider);
    Future<void>(() async {
      try {
        if (userId == null) {
          await service.stopListening();
          return;
        }
        await service.startListening(userId);
      } catch (_) {
        // Notifications are best-effort; never crash the UI tree.
      }
    });
  });
});
