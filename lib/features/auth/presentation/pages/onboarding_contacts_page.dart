import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/providers/session_data_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../sos/presentation/providers/emergency_contacts_provider.dart';

/// Mandatory emergency contacts registration before Home.
class OnboardingContactsPage extends ConsumerStatefulWidget {
  const OnboardingContactsPage({super.key});

  @override
  ConsumerState<OnboardingContactsPage> createState() =>
      _OnboardingContactsPageState();
}

class _OnboardingContactsPageState
    extends ConsumerState<OnboardingContactsPage> {
  final _formKey = GlobalKey<FormState>();
  final List<_ContactInput> _contacts = [_ContactInput(), _ContactInput()];
  bool _isSaving = false;

  @override
  void dispose() {
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  void _addContact() {
    if (_contacts.length >= 10) return;
    setState(() => _contacts.add(_ContactInput()));
  }

  void _removeContact(int index) {
    if (_contacts.length <= 2) return;
    final removed = _contacts.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).value?.session?.user.id;
    if (userId == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Contactos de emergencia')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contactos obligatorios',
                style: AppTextStyles.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Agrega mínimo 2 y máximo 10 contactos para activar SOS y entrar al inicio.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(_contacts.length, (index) {
                return _ContactFormCard(
                  index: index,
                  contact: _contacts[index],
                  canRemove: _contacts.length > 2,
                  onRemove: () => _removeContact(index),
                );
              }),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _contacts.length >= 10 ? null : _addContact,
                icon: const Icon(Icons.add),
                label: const Text('Agregar contacto'),
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: AppStrings.save,
                isLoading: _isSaving,
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _isSaving = true);
                        try {
                          final repository = ref.read(
                            emergencyContactsRepositoryProvider,
                          );
                          for (final contact in _contacts) {
                            await repository.addContact(
                              userId: userId,
                              name: contact.name.text.trim(),
                              phone: contact.phone.text.trim(),
                              relationship:
                                  contact.relationship.text.trim().isEmpty
                                  ? null
                                  : contact.relationship.text.trim(),
                            );
                          }
                          ref.invalidate(emergencyContactsProvider(userId));
                          ref.read(sessionDataVersionProvider.notifier).state++;
                          ref.invalidate(onboardingStatusProvider);
                          if (context.mounted) {
                            context.go(AppStrings.routeSplash);
                          }
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactFormCard extends StatelessWidget {
  final int index;
  final _ContactInput contact;
  final bool canRemove;
  final VoidCallback onRemove;

  const _ContactFormCard({
    required this.index,
    required this.contact,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contacto ${index + 1}',
                  style: AppTextStyles.labelMedium,
                ),
              ),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.error,
              ),
            ],
          ),
          TextFormField(
            controller: contact.name,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
              labelText: 'Nombre',
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: contact.phone,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_outlined),
              labelText: 'Teléfono',
            ),
            keyboardType: TextInputType.phone,
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: contact.relationship,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.group_outlined),
              labelText: 'Parentesco (opcional)',
            ),
          ),
        ],
      ),
    );
  }

  static String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }
}

class _ContactInput {
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController relationship = TextEditingController();

  void dispose() {
    name.dispose();
    phone.dispose();
    relationship.dispose();
  }
}
