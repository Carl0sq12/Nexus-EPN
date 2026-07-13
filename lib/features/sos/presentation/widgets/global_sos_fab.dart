import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../utils/sos_actions.dart';

class GlobalSosFab extends ConsumerWidget {
  const GlobalSosFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();

    return SafeArea(
      minimum: const EdgeInsets.only(right: 16, bottom: 12),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Tooltip(
          message: 'Auxilio rápido',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showQuickSosSheet(context),
              customBorder: const CircleBorder(),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.32),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sos_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickSosSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _QuickSosSheet(),
    );
  }
}

class _QuickSosSheet extends ConsumerWidget {
  const _QuickSosSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);

    Future<void> send({required String label, required String type}) async {
      if (userId == null) return;
      try {
        final result = await sendSosWithNotifications(
          ref,
          userId: userId,
          alertLabel: label,
          alertType: type,
        );
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.notifiedContacts == 0
                  ? 'SOS guardado. Ningún contacto tiene la app con ese número.'
                  : 'SOS enviado a ${result.notifiedContacts} contacto(s) en la app',
            ),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo enviar SOS: $e')));
      }
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency_share_outlined,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auxilio rápido', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Elige el tipo de alerta y mantén presionado para enviar.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SosActionTile(
              title: AppStrings.sosPersonalEmergency,
              subtitle: 'Notifica a tus contactos con tu ubicación actual.',
              icon: Icons.personal_injury_outlined,
              color: AppColors.error,
              onConfirmed: () => send(
                label: AppStrings.sosPersonalEmergency,
                type: AppStrings.sosTypePersonal,
              ),
            ),
            const SizedBox(height: 12),
            _SosActionTile(
              title: AppStrings.sosMechanicalProblem,
              subtitle: 'Solicita ayuda por fallas o problemas del vehículo.',
              icon: Icons.build_circle_outlined,
              color: AppColors.warning,
              onConfirmed: () => send(
                label: AppStrings.sosMechanicalProblem,
                type: AppStrings.sosTypeMechanical,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Future<void> Function() onConfirmed;

  const _SosActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _HoldSendButton(color: color, onConfirmed: onConfirmed),
        ],
      ),
    );
  }
}

class _HoldSendButton extends StatefulWidget {
  final Color color;
  final Future<void> Function() onConfirmed;

  const _HoldSendButton({required this.color, required this.onConfirmed});

  @override
  State<_HoldSendButton> createState() => _HoldSendButtonState();
}

class _HoldSendButtonState extends State<_HoldSendButton> {
  static const _holdDuration = Duration(seconds: 2);

  Timer? _timer;
  bool _holding = false;
  bool _sending = false;

  void _startHold(LongPressStartDetails details) {
    if (_sending) return;
    setState(() => _holding = true);
    _timer = Timer(_holdDuration, () async {
      if (!mounted) return;
      setState(() {
        _holding = false;
        _sending = true;
      });
      await widget.onConfirmed();
      if (mounted) {
        setState(() => _sending = false);
      }
    });
  }

  void _cancelHold([LongPressEndDetails? details]) {
    _timer?.cancel();
    if (mounted && _holding) {
      setState(() => _holding = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _startHold,
      onLongPressEnd: _cancelHold,
      onLongPressCancel: _cancelHold,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 42,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (_holding)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_holding)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: _holdDuration,
                builder: (context, value, child) => Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            if (_sending)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.touch_app_outlined, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
