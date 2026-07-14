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
  static const _buttonSize = 62.0;
  static const _screenMargin = 14.0;
  static const _dragSlop = 12.0;
  static const _prefX = 'global_sos_fab_x';
  static const _prefY = 'global_sos_fab_y';

  Offset? _position;
  Offset? _pointerDownGlobal;
  Offset? _positionAtPointerDown;
  bool _dragging = false;
  bool _movedEnough = false;
  bool _sheetOpen = false;

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

  void _openSosOptions() {
    if (!mounted || _sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _QuickSosSheet(),
    ).whenComplete(() {
      _sheetOpen = false;
    });
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
                width: _buttonSize,
                height: _buttonSize,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    _pointerDownGlobal = event.position;
                    _positionAtPointerDown = _position ?? position;
                    _movedEnough = false;
                    _dragging = false;
                  },
                  onPointerMove: (event) {
                    final down = _pointerDownGlobal;
                    final origin = _positionAtPointerDown;
                    if (down == null || origin == null) return;

                    final delta = event.position - down;
                    if (!_movedEnough && delta.distance < _dragSlop) {
                      return;
                    }
                    _movedEnough = true;
                    setState(() {
                      _dragging = true;
                      _position = _clampPosition(origin + delta, size);
                    });
                  },
                  onPointerUp: (_) {
                    final wasDrag = _movedEnough;
                    final next = _clampPosition(
                      _position ?? position,
                      size,
                    );
                    setState(() {
                      _position = next;
                      _dragging = false;
                    });
                    _pointerDownGlobal = null;
                    _positionAtPointerDown = null;
                    _movedEnough = false;

                    if (wasDrag) {
                      _savePosition(next);
                      return;
                    }
                    // Pure tap (no meaningful move) → open options.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _openSosOptions();
                    });
                  },
                  onPointerCancel: (_) {
                    _pointerDownGlobal = null;
                    _positionAtPointerDown = null;
                    _movedEnough = false;
                    if (_dragging) {
                      setState(() => _dragging = false);
                    }
                  },
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 140),
                    scale: _dragging ? 1.06 : 1,
                    child: Material(
                      color: AppColors.error,
                      shape: const CircleBorder(),
                      elevation: _dragging ? 10 : 6,
                      shadowColor: AppColors.error.withValues(alpha: 0.45),
                      child: const SizedBox(
                        width: _buttonSize,
                        height: _buttonSize,
                        child: Icon(
                          Icons.sos_outlined,
                          color: Colors.white,
                          size: 32,
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
        Navigator.of(context).pop();
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
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          title: 'No se pudo enviar SOS',
          message: e.toString(),
          type: AppSnackBarType.error,
        );
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
                            ? 'Elige el tipo de alerta y tócala para enviar.'
                            : 'Toca la alerta para enviarla a tus contactos.',
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
              onSend: () => send(
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
                onSend: () => send(
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

class _SosActionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Future<void> Function() onSend;

  const _SosActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onSend,
  });

  @override
  State<_SosActionTile> createState() => _SosActionTileState();
}

class _SosActionTileState extends State<_SosActionTile> {
  bool _sending = false;

  Future<void> _handleTap() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _sending ? null : _handleTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: AppTextStyles.labelMedium),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
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
              Container(
                width: 58,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _sending
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
