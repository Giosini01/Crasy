import 'package:app_incontri/core/errors/error_message_mapper.dart';
import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:app_incontri/core/widgets/inline_banner.dart';
import 'package:app_incontri/features/auth/presentation/controllers/auth_action_controller.dart';
import 'package:app_incontri/features/auth/presentation/utils/auth_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthMode { signIn, signUp }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  AuthMode _mode = AuthMode.signIn;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(authActionControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_mode == AuthMode.signIn) {
      await controller.signIn(email: email, password: password);
      return;
    }

    await controller.signUp(email: email, password: password);
  }

  void _switchMode(AuthMode mode) {
    if (mode == _mode) {
      return;
    }

    setState(() {
      _mode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isSignIn = _mode == AuthMode.signIn;
    final authAction = ref.watch(authActionControllerProvider);
    final isLoading = authAction.isLoading;
    final errorText = authAction.hasError
        ? ErrorMessageMapper.map(authAction.error!)
        : null;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandWordmark(height: 44),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        isSignIn
                            ? 'Entra e scopri chi c\'e oggi.'
                            : 'Crea il tuo accesso. L\'onboarding arriva subito dopo.',
                        style: context.texts.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _AuthModeSwitch(
                        mode: _mode,
                        onChanged: isLoading ? null : _switchMode,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: AuthValidators.validateEmail,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: isSignIn
                            ? TextInputAction.done
                            : TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            tooltip: _obscurePassword
                                ? 'Mostra password'
                                : 'Nascondi password',
                          ),
                        ),
                        validator: AuthValidators.validatePassword,
                      ),
                      if (!isSignIn) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscurePassword,
                          decoration: const InputDecoration(
                            labelText: 'Conferma password',
                          ),
                          validator: (value) =>
                              AuthValidators.validatePasswordConfirmation(
                                password: _passwordController.text,
                                confirmation: value,
                              ),
                        ),
                      ],
                      if (errorText != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        InlineBanner(message: errorText),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: palette.textSecondary,
                                ),
                              )
                            : Text(isSignIn ? 'Accedi' : 'Crea account'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () => _switchMode(
                                  isSignIn ? AuthMode.signUp : AuthMode.signIn,
                                ),
                          child: Text(
                            isSignIn
                                ? 'Non hai un account? Registrati'
                                : 'Hai gia un account? Accedi',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selettore login/registrazione: pillola con cursore scorrevole, al posto
/// del `SegmentedButton` di serie che stonava con il resto delle forme.
class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          _AuthModeTab(
            label: 'Login',
            selected: mode == AuthMode.signIn,
            onTap: onChanged == null ? null : () => onChanged!(AuthMode.signIn),
          ),
          _AuthModeTab(
            label: 'Registrazione',
            selected: mode == AuthMode.signUp,
            onTap: onChanged == null ? null : () => onChanged!(AuthMode.signUp),
          ),
        ],
      ),
    );
  }
}

class _AuthModeTab extends StatelessWidget {
  const _AuthModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: selected ? palette.border : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.texts.labelMedium?.copyWith(
              color: selected ? palette.textPrimary : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
