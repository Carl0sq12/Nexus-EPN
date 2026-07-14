import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../network/appwrite_client.dart';
import '../providers/appwrite_provider.dart';
import '../providers/device_readiness_provider.dart';

class DeviceReadinessGate extends ConsumerStatefulWidget {
  final Widget child;

  const DeviceReadinessGate({required this.child, super.key});

  @override
  ConsumerState<DeviceReadinessGate> createState() =>
      _DeviceReadinessGateState();
}

class _DeviceReadinessGateState extends ConsumerState<DeviceReadinessGate>
    with WidgetsBindingObserver {
  DateTime? _suppressBlockerUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    setState(() {
      _suppressBlockerUntil = DateTime.now().add(const Duration(seconds: 8));
    });
    ref.invalidate(deviceReadinessProvider);
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      ref.invalidate(deviceReadinessProvider);
      setState(() => _suppressBlockerUntil = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppwriteClientHolder.isInitialized) return widget.child;

    final readiness = ref.watch(deviceReadinessProvider).asData?.value;
    String? userId;
    try {
      userId = ref.watch(currentUserIdProvider);
    } catch (_) {
      userId = null;
    }
    final issue = readiness?.issue ?? DeviceReadinessIssue.none;
    final shouldBlock =
        issue == DeviceReadinessIssue.noInternet ||
        (userId != null && issue != DeviceReadinessIssue.none);
    final suppressingBlocker =
        _suppressBlockerUntil != null &&
        DateTime.now().isBefore(_suppressBlockerUntil!);

    return Stack(
      children: [
        widget.child,
        if (shouldBlock && !suppressingBlocker) _DeviceBlocker(issue: issue),
      ],
    );
  }
}

class _DeviceBlocker extends ConsumerWidget {
  final DeviceReadinessIssue issue;

  const _DeviceBlocker({required this.issue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _contentFor(issue);

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.38),
        child: SafeArea(
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(10, 29, 45, 0.18),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: content.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(content.icon, color: content.color, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    content.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              ref.invalidate(deviceReadinessProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ),
                      if (content.action != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await content.action!();
                              ref.invalidate(deviceReadinessProvider);
                            },
                            icon: Icon(content.actionIcon),
                            label: Text(content.actionLabel),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceBlockerContent {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final IconData actionIcon;
  final Future<void> Function()? action;

  const _DeviceBlockerContent({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.actionIcon,
    required this.action,
  });
}

_DeviceBlockerContent _contentFor(DeviceReadinessIssue issue) {
  return switch (issue) {
    DeviceReadinessIssue.noInternet => const _DeviceBlockerContent(
      title: 'Sin conexi?n a internet',
      message:
          'Activa Wi?Fi o datos m?viles y desactiva el modo avi?n. Nexus Campus necesita conexi?n para viajes, solicitudes, mensajes y SOS.',
      icon: Icons.signal_wifi_connected_no_internet_4_outlined,
      color: AppColors.warning,
      actionLabel: 'Ajustes',
      actionIcon: Icons.settings_outlined,
      action: null,
    ),
    DeviceReadinessIssue.locationServiceDisabled => _DeviceBlockerContent(
      title: 'GPS desactivado',
      message:
          'Activa la ubicaci?n del dispositivo. Sin GPS no se puede crear viajes, navegar, marcar paradas ni enviar SOS con ubicaci?n.',
      icon: Icons.location_disabled_outlined,
      color: AppColors.error,
      actionLabel: 'Activar GPS',
      actionIcon: Icons.gps_fixed,
      action: Geolocator.openLocationSettings,
    ),
    DeviceReadinessIssue.locationPermissionDenied => _DeviceBlockerContent(
      title: 'Permiso de ubicaci?n requerido',
      message:
          'Permite el acceso a ubicaci?n para que la app pueda calcular rutas, navegaci?n y auxilio.',
      icon: Icons.location_off_outlined,
      color: AppColors.error,
      actionLabel: 'Permitir',
      actionIcon: Icons.check_circle_outline,
      action: () async {
        await Geolocator.requestPermission();
      },
    ),
    DeviceReadinessIssue.locationPermissionDeniedForever => _DeviceBlockerContent(
      title: 'Ubicaci?n bloqueada',
      message:
          'La ubicaci?n est? bloqueada para Nexus Campus. Act?vala desde los ajustes de la app para continuar.',
      icon: Icons.app_blocking_outlined,
      color: AppColors.error,
      actionLabel: 'Abrir ajustes',
      actionIcon: Icons.settings_outlined,
      action: Geolocator.openAppSettings,
    ),
    DeviceReadinessIssue.none => const _DeviceBlockerContent(
      title: '',
      message: '',
      icon: Icons.check,
      color: AppColors.success,
      actionLabel: '',
      actionIcon: Icons.check,
      action: null,
    ),
  };
}
