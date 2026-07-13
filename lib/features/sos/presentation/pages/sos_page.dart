import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../utils/sos_actions.dart';
import '../widgets/sos_button.dart';

class SosPage extends ConsumerStatefulWidget {
  const SosPage({super.key});

  @override
  ConsumerState<SosPage> createState() => _SosPageState();
}

class _SosPageState extends ConsumerState<SosPage> {
  String _selectedType = AppStrings.sosTypePersonal;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.userId;
    final isDriver = ref
        .watch(onboardingStatusProvider)
        .maybeWhen(
          data: (status) => status.role == AppStrings.roleDriver,
          orElse: () => false,
        );
    final selectedType = isDriver ? _selectedType : AppStrings.sosTypePersonal;
    final selectedLabel = selectedType == AppStrings.sosTypeMechanical
        ? AppStrings.sosMechanicalProblem
        : AppStrings.sosPersonalEmergency;

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
                isDriver
                    ? 'La alerta se envía dentro de Nexus Campus a tus contactos '
                          'de emergencia. Usa auxilio mecánico solo para problemas del vehículo.'
                    : 'La alerta se envía dentro de Nexus Campus a tus contactos '
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
                  if (isDriver) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SosTypeButton(
                        label: AppStrings.sosMechanicalProblem,
                        icon: Icons.build_outlined,
                        isSelected:
                            _selectedType == AppStrings.sosTypeMechanical,
                        onTap: () => setState(
                          () => _selectedType = AppStrings.sosTypeMechanical,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            SosButton(
              onSosTriggered: () async {
                if (userId == null) return;
                try {
                  final result = await sendSosWithNotifications(
                    ref,
                    userId: userId,
                    alertLabel: selectedLabel,
                    alertType: selectedType,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.notifiedContacts == 0
                            ? 'SOS guardado. Ningún contacto tiene la app con ese número.'
                            : 'SOS enviado a ${result.notifiedContacts} contacto(s) en la app',
                      ),
                    ),
                  );
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
