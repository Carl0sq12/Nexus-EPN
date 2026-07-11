import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/emergency_contacts_provider.dart';
import '../providers/sos_provider.dart';
import '../widgets/sos_button.dart';

class SosPage extends ConsumerStatefulWidget {
  const SosPage({super.key});

  @override
  ConsumerState<SosPage> createState() => _SosPageState();
}

class _SosPageState extends ConsumerState<SosPage> {
  String _selectedType = AppStrings.sosTypePersonal;

  String get _selectedLabel => _selectedType == AppStrings.sosTypeMechanical
      ? AppStrings.sosMechanicalProblem
      : AppStrings.sosPersonalEmergency;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.sosTitle),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'La alerta se envía dentro de Nexus Campus a tus contactos '
                'de emergencia que tengan la app con el mismo número celular.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _SosTypeButton(
                      label: AppStrings.sosPersonalEmergency,
                      icon: Icons.personal_injury_outlined,
                      isSelected: _selectedType == AppStrings.sosTypePersonal,
                      onTap: () => setState(
                        () => _selectedType = AppStrings.sosTypePersonal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SosTypeButton(
                      label: AppStrings.sosMechanicalProblem,
                      icon: Icons.build_outlined,
                      isSelected: _selectedType == AppStrings.sosTypeMechanical,
                      onTap: () => setState(
                        () => _selectedType = AppStrings.sosTypeMechanical,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SosButton(
              onSosTriggered: () async {
                if (userId == null) return;
                try {
                  final location = await ref.read(
                    currentLocationProvider.future,
                  );
                  await ref.read(sosNotifierProvider.notifier).sendSosAlert(
                        userId,
                        location.latitude,
                        location.longitude,
                        _selectedLabel,
                        _selectedType,
                      );
                  if (!context.mounted) return;
                  final sosState = ref.read(sosNotifierProvider);
                  if (sosState.hasError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(sosState.error.toString())),
                    );
                    return;
                  }

                  try {
                    final notified = await _notifyEmergencyContactsInApp(
                      ref,
                      userId,
                      location.latitude,
                      location.longitude,
                      _selectedLabel,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          notified == 0
                              ? 'SOS guardado. Ningún contacto tiene la app con ese número.'
                              : 'SOS enviado a $notified contacto(s) en la app',
                        ),
                      ),
                    );
                  } catch (notifyError) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'SOS guardado, pero no se pudo notificar contactos: $notifyError',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No se pudo enviar SOS: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.sosHoldToSend.toUpperCase(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SosTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SosTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sends in-app notifications (same channel as trip/chat alerts) to emergency
/// contacts that are registered users matched by phone number.
Future<int> _notifyEmergencyContactsInApp(
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
