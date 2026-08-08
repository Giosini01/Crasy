import 'package:app_incontri/core/errors/error_message_mapper.dart';
import 'package:app_incontri/core/theme/app_colors.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authAction = ref.watch(authActionControllerProvider);
    final isLoading = authAction.isLoading;
    final errorText = authAction.hasError
        ? ErrorMessageMapper.map(authAction.error!)
        : null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surfaceMuted],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Daily', style: theme.textTheme.displayMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _mode == AuthMode.signIn
                              ? 'Entra e scopri chi c\'e oggi.'
                              : 'Crea il tuo accesso. L\'onboarding arriva subito dopo.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SegmentedButton<AuthMode>(
                          segments: const [
                            ButtonSegment<AuthMode>(
                              value: AuthMode.signIn,
                              label: Text('Login'),
                            ),
                            ButtonSegment<AuthMode>(
                              value: AuthMode.signUp,
                              label: Text('Registrazione'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _mode = selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: AuthValidators.validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          validator: AuthValidators.validatePassword,
                        ),
                        if (_mode == AuthMode.signUp) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
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
                          Text(
                            errorText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: Text(
                            isLoading
                                ? 'Attendi...'
                                : _mode == AuthMode.signIn
                                ? 'Accedi'
                                : 'Crea account',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _mode = _mode == AuthMode.signIn
                                        ? AuthMode.signUp
                                        : AuthMode.signIn;
                                  });
                                },
                          child: Text(
                            _mode == AuthMode.signIn
                                ? 'Non hai un account? Registrati'
                                : 'Hai gia un account? Accedi',
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
      ),
    );
  }
}
