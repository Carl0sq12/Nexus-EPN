import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../map/presentation/providers/map_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/emergency_contacts_provider.dart';
import '../providers/sos_provider.dart';

class SosSendResult {
  final int notifiedContacts;

  const SosSendResult({required this.notifiedContacts});
}

Future<SosSendResult> sendSosWithNotifications(
  WidgetRef ref, {
  required String userId,
  required String alertLabel,
  required String alertType,
}) async {
  final location = await ref.read(currentLocationProvider.future);

  await ref
      .read(sosNotifierProvider.notifier)
      .sendSosAlert(
        userId,
        location.latitude,
        location.longitude,
        alertLabel,
        alertType,
      );

  final sosState = ref.read(sosNotifierProvider);
  if (sosState.hasError) {
    throw Exception(sosState.error.toString());
  }

  final notifiedContacts = await notifyEmergencyContactsInApp(
    ref,
    userId,
    location.latitude,
    location.longitude,
    alertLabel,
  );

  return SosSendResult(notifiedContacts: notifiedContacts);
}

/// Sends in-app notifications to emergency contacts that are registered users
/// matched by phone number.
Future<int> notifyEmergencyContactsInApp(
  WidgetRef ref,
  String userId,
  double latitude,
  double longitude,
  String alertLabel,
) async {
  final contacts = await ref
      .read(emergencyContactsRepositoryProvider)
      .getContacts(userId);
  if (contacts.isEmpty) {
    throw Exception(
      'No tienes contactos de emergencia. Agrégalos en tu perfil.',
    );
  }

  final profile = await ref.read(profileProvider(userId).future);
  final mapsLink =
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  final now = DateTime.now().toLocal();
  final timeLabel =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final body =
      '${profile.fullName} activó SOS ($alertLabel).\n'
      'Ubicación en tiempo real: $mapsLink\n'
      'Coords: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)} · $timeLabel';

  final notificationDs = ref.read(notificationRemoteDatasourceProvider);
  final profileRepo = ref.read(profileRepositoryProvider);
  final notifiedIds = <String>{};
  var notified = 0;

  for (final contact in contacts) {
    final matched = await profileRepo.findByPhone(contact.phone);
    if (matched == null) continue;
    if (matched.id == userId) continue;
    if (notifiedIds.contains(matched.id)) continue;

    await notificationDs.create(
      userId: matched.id,
      title: 'SOS · $alertLabel',
      body: body,
      type: 'sos',
      relatedId: userId,
    );
    ref.invalidate(notificationsProvider(matched.id));
    notifiedIds.add(matched.id);
    notified++;
  }

  return notified;
}
