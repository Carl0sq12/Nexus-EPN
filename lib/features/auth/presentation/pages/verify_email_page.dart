import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../providers/auth_provider.dart';

/// Mandatory screen when Appwrite reports an unverified email.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _resending = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correo reenviado. Revisa bandeja de entrada y spam.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authStateProvider).asData?.value;
    final email = session?.email ?? 'tu correo institucional';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verifica tu correo',
                style: AppTextStyles.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Debes confirmar el enlace enviado a $email antes de continuar. '
                'Si no llega, revisa spam o reenvíalo.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Ya verifiqué',
                onPressed: () async {
                  await ref
                      .read(authSessionControllerProvider.notifier)
                      .refresh();
                  ref.invalidate(onboardingStatusProvider);
                  if (context.mounted) context.go(AppStrings.routeSplash);
                },
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: _resending ? 'Enviando...' : 'Reenviar correo',
                isOutlined: true,
                onPressed: _resending ? null : _resend,
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: AppStrings.logout,
                isOutlined: true,
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go(AppStrings.routeLogin);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
