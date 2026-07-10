import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../map/presentation/providers/map_provider.dart';
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
    final userId = authState.value?.session?.user.id;

    return Scaffold(
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
                final location = await ref.read(currentLocationProvider.future);
                await ref
                    .read(sosNotifierProvider.notifier)
                    .sendSosAlert(
                      userId,
                      location.latitude,
                      location.longitude,
                      _selectedLabel,
                      _selectedType,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(AppStrings.sosSent)),
                  );
                }
                if (context.mounted) {
                  await _notifyEmergencyContacts(
                    ref,
                    userId,
                    location.latitude,
                    location.longitude,
                    _selectedLabel,
                  );
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

Future<void> _notifyEmergencyContacts(
  WidgetRef ref,
  String userId,
  double latitude,
  double longitude,
  String alertLabel,
) async {
  try {
    final contacts = await ref
        .read(emergencyContactsRepositoryProvider)
        .getContacts(userId);
    if (contacts.isEmpty) return;

    final mapsLink = 'https://maps.google.com/maps?q=$latitude,$longitude';
    final message = '¡$alertLabel! Necesito ayuda. Mi ubicación: $mapsLink';

    for (final contact in contacts) {
      final uri = Uri.parse(
        'sms:${contact.phone}?body=${Uri.encodeFull(message)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  } catch (_) {
    // Si falla la notificación, la alerta ya quedó registrada en sos_alerts
  }
}
