import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../presentation/providers/auth_preferences_provider.dart';
import '../../presentation/providers/auth_provider.dart';

/// Login page with Coastal Wave design, form card, and biometric option.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localAuth = LocalAuthentication();
  bool _rememberMe = false;
  bool _isLoadingBiometric = false;
  bool _loadedPreferences = false;
  bool _obscurePassword = true;
  String _selectedRole = AppStrings.rolePassenger;

  static final RegExp _emailRegex = RegExp(
    r'^[\w.+-]+@epn\.edu\.ec$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoadingBiometric = true);
    try {
      // Business rule: biometric login never uses stored credentials. It only
      // unlocks an already valid Appwrite session persisted by the SDK.
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay una sesión válida guardada.')),
          );
        }
        return;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este dispositivo no soporta autenticación biométrica.',
              ),
            ),
          );
        }
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Usá tu huella para iniciar sesión',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated && mounted) {
        final roleMatches = await _ensureSelectedRole(userId);
        if (!roleMatches) return;
        ref.invalidate(onboardingStatusProvider);
        if (!mounted) return;
        context.go(AppStrings.routeSplash);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error biométrico: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingBiometric = false);
    }
  }

  Future<bool> _ensureSelectedRole(
    String userId, {
    String? fallbackRole,
  }) async {
    String? actualRole = fallbackRole;
    try {
      final profile = await ref.read(profileProvider(userId).future);
      actualRole = profile.role;
    } catch (_) {
      actualRole = fallbackRole;
    }

    if (actualRole == null || actualRole == _selectedRole) return true;

    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return false;

    final expected = _selectedRole == AppStrings.roleDriver
        ? 'conductor'
        : 'pasajero';
    final actual = actualRole == AppStrings.roleDriver
        ? 'conductor'
        : 'pasajero';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Esta cuenta está registrada como $actual. Selecciona $actual para ingresar, no $expected.',
        ),
      ),
    );
    return false;
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
        const Text('Entrar como', style: AppTextStyles.labelMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RoleOption(
                label: 'Pasajero',
                icon: Icons.person_outline,
                isSelected: _selectedRole == AppStrings.rolePassenger,
                onTap: () =>
                    setState(() => _selectedRole = AppStrings.rolePassenger),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleOption(
                label: 'Conductor',
                icon: Icons.directions_car_outlined,
                isSelected: _selectedRole == AppStrings.roleDriver,
                onTap: () =>
                    setState(() => _selectedRole = AppStrings.roleDriver),
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
    final preferencesAsync = ref.watch(authPreferencesProvider);
    final biometricEnabled =
        preferencesAsync.asData?.value.biometricEnabled ?? false;

    final preferences = preferencesAsync.asData?.value;
    if (preferences != null && !_loadedPreferences) {
      _loadedPreferences = true;
      _rememberMe = preferences.rememberAccount;
      if (preferences.rememberedEmail != null) {
        _emailController.text = preferences.rememberedEmail!;
      }
    }

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
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 72,
                  height: 72,
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
                  child: const Icon(Icons.route, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.appName,
                  style: AppTextStyles.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.appTagline,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
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
                      _roleSelector(),
                      const SizedBox(height: 20),
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
                          if (v == null || v.isEmpty) return 'Campo requerido';
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? false),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Recordar este dispositivo',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: TextButton(
                              onPressed: () =>
                                  context.go(AppStrings.routeForgot),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryMid,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        label: AppStrings.login.toUpperCase(),
                        isLoading: authActionState.isLoading,
                        onPressed: authActionState.isLoading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                await ref
                                    .read(authProvider.notifier)
                                    .signIn(
                                      _emailController.text.trim(),
                                      _passwordController.text,
                                    );
                                final authResult = ref.read(authProvider);
                                if (authResult.hasError ||
                                    authResult.value == null) {
                                  return;
                                }
                                final roleMatches = await _ensureSelectedRole(
                                  authResult.value!.id,
                                  fallbackRole: authResult.value!.role,
                                );
                                if (!roleMatches) return;
                                await ref
                                    .read(authPreferencesProvider.notifier)
                                    .saveRememberedAccount(
                                      remember: _rememberMe,
                                      email: _rememberMe
                                          ? _emailController.text.trim()
                                          : null,
                                    );
                                ref.invalidate(onboardingStatusProvider);
                                if (!context.mounted) return;
                                context.go(AppStrings.routeSplash);
                              },
                      ),
                      if (biometricEnabled) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: AppColors.outlineVariant),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'O ACCEDE CON',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.outline,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: AppColors.outlineVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingBiometric
                                ? null
                                : _handleBiometricLogin,
                            icon: const Icon(
                              Icons.fingerprint,
                              color: AppColors.primaryMid,
                            ),
                            label: Text(
                              'Ingresar con huella/Face ID',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.primaryMid,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.primarySoft,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppStrings.routeRegister),
                      child: Text(
                        AppStrings.register,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
    return Material(
      color: isSelected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
