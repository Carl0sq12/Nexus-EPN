import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/session_data_provider.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/widgets/async_value_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ratings/domain/entities/rating.dart';
import '../../../ratings/presentation/providers/rating_provider.dart';
import '../../../sos/presentation/providers/emergency_contacts_provider.dart';
import '../providers/profile_provider.dart';

/// Profile page with Campus Impact card, settings, emergency contacts, and logout.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = authState.value?.session?.user.id;

    if (userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppStrings.routeLogin);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final profileAsync = ref.watch(profileProvider(userId));
    final contactsAsync = ref.watch(emergencyContactsProvider(userId));
    final ratingsAsync = ref.watch(ratingsForUserProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AsyncValueWidget(
        value: profileAsync,
        builder: (profile) {
          final initials = profile.fullName
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join();
          final isDriver = profile.role == AppStrings.roleDriver;
          final roleLabel = isDriver ? 'Conductor' : 'Pasajero';

          return SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 220,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: profile.avatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      profile.avatarUrl!,
                                    )
                                  : null,
                              backgroundColor: AppColors.surface,
                              child: profile.avatarUrl == null
                                  ? Text(
                                      initials,
                                      style: AppTextStyles.displayLarge
                                          .copyWith(
                                            color: AppColors.primary,
                                            fontSize: 36,
                                          ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMid,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile.fullName,
                          style: AppTextStyles.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    roleLabel,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Color(0xFFB78103),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatAverageRating(ratingsAsync),
                                    style: const TextStyle(
                                      color: Color(0xFFB78103),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(13, 111, 148, 0.08),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.eco,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'IMPACTO AMBIENTAL',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '42',
                                          style: AppTextStyles.displayLarge
                                              .copyWith(
                                                color: Colors.white,
                                                fontSize: 32,
                                              ),
                                        ),
                                        Text(
                                          'VIAJES COMPARTIDOS',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                                fontSize: 11,
                                                letterSpacing: 1,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '12kg',
                                          style: AppTextStyles.displayLarge
                                              .copyWith(
                                                color: Colors.white,
                                                fontSize: 32,
                                              ),
                                        ),
                                        Text(
                                          'CO₂ AHORRADO',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                                fontSize: 11,
                                                letterSpacing: 1,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(13, 111, 148, 0.08),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _SettingsTile(
                                icon: Icons.person,
                                title: 'Información Personal',
                                subtitle: 'Nombre, correo y teléfono',
                                onTap: () =>
                                    context.push(AppStrings.routeProfileEdit),
                              ),
                              _SettingsTile(
                                icon: Icons.shield,
                                title: 'Seguridad',
                                subtitle: 'Contraseña y biometría',
                                onTap: () {},
                              ),
                              _SettingsTile(
                                icon: Icons.notifications_active,
                                title: 'Notificaciones',
                                subtitle: 'Alertas y sonidos',
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Contactos de Emergencia',
                              style: AppTextStyles.titleMedium,
                            ),
                            TextButton(
                              onPressed: () =>
                                  _showAddContactDialog(context, ref, userId),
                              child: Text(
                                'Agregar',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        contactsAsync.when(
                          loading: () => const SizedBox(
                            height: 60,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (e, _) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Error: $e',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                          data: (contacts) {
                            if (contacts.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(13, 111, 148, 0.08),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.primarySoft,
                                      child: Icon(
                                        Icons.person,
                                        color: AppColors.primaryMid,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Aún no tienes contactos',
                                            style: AppTextStyles.bodyMedium,
                                          ),
                                          Text(
                                            'Agrega contactos de emergencia',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Column(
                              children: contacts
                                  .map(
                                    (contact) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color.fromRGBO(
                                              13,
                                              111,
                                              148,
                                              0.08,
                                            ),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor:
                                                AppColors.primarySoft,
                                            child: Icon(
                                              Icons.person,
                                              color: AppColors.primaryMid,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  contact.name,
                                                  style:
                                                      AppTextStyles.bodyMedium,
                                                ),
                                                Text(
                                                  contact.phone,
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                        fontSize: 12,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: AppColors.error,
                                              size: 20,
                                            ),
                                            onPressed: () => _deleteContact(
                                              context,
                                              ref,
                                              userId,
                                              contact.id,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(authProvider.notifier).signOut();
                              if (context.mounted) {
                                context.go(AppStrings.routeLogin);
                              }
                            },
                            icon: const Icon(
                              Icons.logout,
                              color: AppColors.error,
                            ),
                            label: Text(
                              AppStrings.logout,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.error,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A settings row with icon, title, subtitle, and chevron.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryMid, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAddContactDialog(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  final currentContacts = await ref.read(
    emergencyContactsProvider(userId).future,
  );
  if (currentContacts.length >= 10) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 10 contactos de emergencia')),
      );
    }
    return;
  }

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final relationshipController = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Agregar contacto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Debes mantener entre 2 y 10 contactos de emergencia.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: María',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              hintText: '+593 99 999 9999',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: relationshipController,
            decoration: const InputDecoration(
              labelText: 'Parentesco (opcional)',
              hintText: 'Ej: Madre, Hermano',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = nameController.text.trim();
            final phone = phoneController.text.trim();
            if (name.isEmpty || phone.isEmpty) return;
            final latestContacts = await ref.read(
              emergencyContactsProvider(userId).future,
            );
            if (latestContacts.length >= 10) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Máximo 10 contactos de emergencia'),
                  ),
                );
              }
              return;
            }
            await ref
                .read(emergencyContactsRepositoryProvider)
                .addContact(
                  userId: userId,
                  name: name,
                  phone: phone,
                  relationship: relationshipController.text.trim().isEmpty
                      ? null
                      : relationshipController.text.trim(),
                );
            ref.invalidate(emergencyContactsProvider(userId));
            ref.read(sessionDataVersionProvider.notifier).state++;
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

Future<void> _deleteContact(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String contactId,
) async {
  final contacts = await ref.read(emergencyContactsProvider(userId).future);
  if (contacts.length <= 2) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes mantener al menos 2 contactos')),
      );
    }
    return;
  }
  await ref.read(emergencyContactsRepositoryProvider).deleteContact(contactId);
  ref.invalidate(emergencyContactsProvider(userId));
  ref.read(sessionDataVersionProvider.notifier).state++;
}

String _formatAverageRating(AsyncValue<List<Rating>> ratingsAsync) {
  return ratingsAsync.maybeWhen(
    data: (ratings) {
      if (ratings.isEmpty) return '0.0';
      final total = ratings.fold<int>(0, (sum, rating) => sum + rating.score);
      return (total / ratings.length).toStringAsFixed(1);
    },
    orElse: () => '--',
  );
}
