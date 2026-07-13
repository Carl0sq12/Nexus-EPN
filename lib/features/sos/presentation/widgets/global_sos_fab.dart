import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../utils/sos_actions.dart';

class GlobalSosFab extends ConsumerStatefulWidget {
  const GlobalSosFab({super.key});

  @override
  ConsumerState<GlobalSosFab> createState() => _GlobalSosFabState();
}

class _GlobalSosFabState extends ConsumerState<GlobalSosFab> {
  static const _holdDuration = Duration(seconds: 3);
  static const _buttonSize = 62.0;
  static const _screenMargin = 14.0;
  static const _prefX = 'global_sos_fab_x';
  static const _prefY = 'global_sos_fab_y';

  Timer? _holdTimer;
  bool _holding = false;
  bool _sending = false;
  bool _holdTriggered = false;
  Offset? _position;
  Offset? _dragStartPosition;
  bool _dragging = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startQuickHold(TapDownDetails details) {
    if (_sending) return;
    _holdTimer?.cancel();
    setState(() {
      _holding = true;
      _holdTriggered = false;
    });
    _holdTimer = Timer(_holdDuration, () async {
      if (!mounted || _sending) return;
      setState(() {
        _holding = false;
        _sending = true;
        _holdTriggered = true;
      });
      await _sendQuickAuxilio();
      if (mounted) {
        setState(() => _sending = false);
      }
    });
  }

  void _cancelQuickHold() {
    _holdTimer?.cancel();
    if (mounted && _holding) {
      setState(() => _holding = false);
    }
  }

  Future<void> _savePosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefX, position.dx);
    await prefs.setDouble(_prefY, position.dy);
  }

  Future<void> _restorePosition(Size size) async {
    if (_position != null) return;
    final prefs = await SharedPreferences.getInstance();
    final storedX = prefs.getDouble(_prefX);
    final storedY = prefs.getDouble(_prefY);
    if (!mounted) return;
    setState(() {
      _position = _clampPosition(
        Offset(
          storedX ?? size.width - _buttonSize - _screenMargin,
          storedY ?? size.height * 0.52,
        ),
        size,
      );
    });
  }

  Offset _clampPosition(Offset position, Size size) {
    final maxX = math.max(
      _screenMargin,
      size.width - _buttonSize - _screenMargin,
    );
    final maxY = math.max(
      _screenMargin,
      size.height - _buttonSize - _screenMargin,
    );
    return Offset(
      position.dx.clamp(_screenMargin, maxX).toDouble(),
      position.dy.clamp(_screenMargin, maxY).toDouble(),
    );
  }

  Future<void> _sendQuickAuxilio() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final result = await sendSosWithNotifications(
        ref,
        userId: userId,
        alertLabel: AppStrings.sosPersonalEmergency,
        alertType: AppStrings.sosTypePersonal,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        title: 'Auxilio enviado',
        message: result.notifiedContacts == 0
            ? 'La alerta quedó guardada, pero ningún contacto tiene la app con ese número.'
            : 'Se notificó a ${result.notifiedContacts} contacto(s) con tu ubicación.',
        type: result.notifiedContacts == 0
            ? AppSnackBarType.warning
            : AppSnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        title: 'No se pudo enviar auxilio',
        message: e.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restorePosition(size);
          });
          final position = _clampPosition(
            _position ??
                Offset(
                  size.width - _buttonSize - _screenMargin,
                  size.height * 0.52,
                ),
            size,
          );

          return Stack(
            children: [
              Positioned(
                left: position.dx,
                top: position.dy,
                child: Tooltip(
                  message:
                      'Arrastra para mover. Mantén 3 segundos para auxilio rápido.',
                  child: Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      onPanStart: (_) {
                        _cancelQuickHold();
                        _dragStartPosition = _position ?? position;
                        setState(() => _dragging = true);
                      },
                      onPanUpdate: (details) {
                        final current =
                            _position ?? _dragStartPosition ?? position;
                        setState(() {
                          _position = _clampPosition(
                            current + details.delta,
                            size,
                          );
                        });
                      },
                      onPanEnd: (_) {
                        final next = _clampPosition(
                          _position ?? position,
                          size,
                        );
                        setState(() {
                          _position = next;
                          _dragging = false;
                        });
                        _savePosition(next);
                      },
                      onPanCancel: () {
                        setState(() => _dragging = false);
                      },
                      onTapDown: _dragging ? null : _startQuickHold,
                      onTapUp: (_) => _cancelQuickHold(),
                      onTapCancel: _cancelQuickHold,
                      onTap: () {
                        if (_dragging) return;
                        if (_holdTriggered) {
                          _holdTriggered = false;
                          return;
                        }
                        if (!_sending) _showQuickSosSheet(context);
                      },
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 140),
                        scale: _dragging ? 1.06 : 1,
                        child: Container(
                          width: _buttonSize,
                          height: _buttonSize,
                          decoration: BoxDecoration(
                            color: _sending
                                ? AppColors.textSecondary
                                : AppColors.error,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.32),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_holding)
                                TweenAnimationBuilder<double>(
                                  key: UniqueKey(),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: _holdDuration,
                                  builder: (context, value, child) => SizedBox(
                                    width: _buttonSize,
                                    height: _buttonSize,
                                    child: CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: 4,
                                      color: Colors.white,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_sending)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.sos_outlined,
                                  color: Colors.white,
                                  size: 32,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
    final isDriver = ref
        .watch(onboardingStatusProvider)
        .maybeWhen(
          data: (status) => status.role == AppStrings.roleDriver,
          orElse: () => false,
        );

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
                        isDriver
                            ? 'Elige el tipo de alerta y mantén presionado para enviar.'
                            : 'Mantén presionado para enviar una alerta de auxilio.',
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
            if (isDriver) ...[
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
  static const _holdDuration = Duration(seconds: 3);

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
