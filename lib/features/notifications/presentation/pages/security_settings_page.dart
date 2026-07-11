import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  static const _tripNotifsKey = 'pref_trip_notifications';
  static const _chatNotifsKey = 'pref_chat_notifications';

  bool _tripNotifs = true;
  bool _chatNotifs = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tripNotifs = prefs.getBool(_tripNotifsKey) ?? true;
      _chatNotifs = prefs.getBool(_chatNotifsKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Seguridad y alertas'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Preferencias de seguridad',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Controla qué alertas quieres recibir en el dispositivo.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Nuevos viajes disponibles'),
                  value: _tripNotifs,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _tripNotifs = v);
                    _set(_tripNotifsKey, v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Mensajes de chat'),
                  value: _chatNotifs,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _chatNotifs = v);
                    _set(_chatNotifsKey, v);
                  },
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.sos, color: AppColors.error),
                  title: const Text('SOS'),
                  subtitle: const Text(
                    'Al activar SOS se notifica dentro de la app a tus '
                    'contactos de emergencia registrados con el mismo celular.',
                  ),
                  onTap: () => context.push('/sos'),
                ),
              ],
            ),
    );
  }
}
