import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../presentation/providers/auth_provider.dart';

/// Register page with role selection cards and Sky Drift design.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _role = AppStrings.rolePassenger;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static final RegExp _emailRegex = RegExp(
    r'^[\w.+-]+@epn\.edu\.ec$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required IconData prefixIcon,
    required String labelText,
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.primarySoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.secondary),
      suffixIcon: suffixIcon,
      labelText: labelText,
      hintText: hintText,
    );
  }

  Widget _roleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de cuenta', style: AppTextStyles.labelMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RoleOption(
                label: 'Pasajero',
                icon: Icons.person,
                isSelected: _role == AppStrings.rolePassenger,
                onTap: () => setState(() => _role = AppStrings.rolePassenger),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleOption(
                label: 'Conductor',
                icon: Icons.directions_car,
                isSelected: _role == AppStrings.roleDriver,
                onTap: () => setState(() => _role = AppStrings.roleDriver),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authActionState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next is AsyncError) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.error.toString())));
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go(AppStrings.routeLogin),
                ),
                const SizedBox(height: 48),
                const Text('Crear cuenta', style: AppTextStyles.displayLarge),
                const SizedBox(height: 4),
                const Text(
                  'Solo correos institucionales @epn.edu.ec',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 24),
                _roleSelector(),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fullNameController,
                  decoration: _decoration(
                    prefixIcon: Icons.person_outline,
                    labelText: 'Nombre completo',
                    hintText: 'Ej: Juan Pérez',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo requerido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _decoration(
                    prefixIcon: Icons.email_outlined,
                    labelText: AppStrings.emailLabel,
                    hintText: AppStrings.emailHint,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo requerido';
                    if (!_emailRegex.hasMatch(v.trim())) {
                      return AppStrings.errorEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _decoration(
                    prefixIcon: Icons.lock_outlined,
                    labelText: AppStrings.passwordLabel,
                    hintText: AppStrings.passwordHint,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.secondary,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return AppStrings.errorPasswordShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _decoration(
                    prefixIcon: Icons.lock_outlined,
                    labelText: 'Confirmar contraseña',
                    hintText: 'Repite la contraseña',
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.secondary,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                CustomButton(
                  label: AppStrings.register,
                  isLoading: authActionState.isLoading,
                  onPressed: authActionState.isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          final user = await ref
                              .read(authProvider.notifier)
                              .signUp(
                                _emailController.text.trim().toLowerCase(),
                                _passwordController.text,
                                _role,
                                _fullNameController.text.trim().isEmpty
                                    ? null
                                    : _fullNameController.text.trim(),
                              );
                          if (user == null) return;
                          if (!context.mounted) return;
                          ref.invalidate(onboardingStatusProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cuenta creada. Verifica tu correo para continuar.',
                              ),
                            ),
                          );
                          context.go(AppStrings.routeSplash);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: 2,
          ),
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.primary : AppColors.secondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
