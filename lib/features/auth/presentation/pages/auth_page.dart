import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/auth/presentation/controllers/auth_action_controller.dart';
import 'package:crasy/features/auth/presentation/utils/auth_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Entrare in CRASY.
///
/// Email e password, e basta. La schermata si apre solo quando serve davvero —
/// per partecipare, votare o avere un profilo — perche' le challenge si possono
/// guardare senza registrarsi: chi arriva qui ha gia' visto cosa c'e' in palio,
/// e sa perche' gli si sta chiedendo un indirizzo.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _signingUp = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final action = ref.watch(authActionControllerProvider);
    final error = action.error;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xl,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                const CrasyWordmark(size: 28),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  _signingUp ? 'CREA IL TUO\nACCOUNT' : 'BENTORNATO',
                  style: texts.displaySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _signingUp
                      ? 'Ti serve per partecipare alle challenge e per '
                            'ricevere i premi che vinci.'
                      : 'Entra e riprendi da dove avevi lasciato.',
                  style: texts.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: AuthValidators.validateEmail,
                  decoration: const InputDecoration(
                    labelText: 'EMAIL',
                    hintText: 'tu@esempio.it',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: AuthValidators.validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'PASSWORD',
                    hintText: 'almeno 8 caratteri',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  InlineBanner(message: ErrorMessageMapper.map(error)),
                ],
                const SizedBox(height: AppSpacing.xl),
                CrasyButton(
                  label: _signingUp ? 'Crea account' : 'Entra',
                  loading: action.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => setState(() => _signingUp = !_signingUp),
                  child: Text(
                    _signingUp
                        ? 'Ho gia\' un account'
                        : 'Non ho ancora un account',
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.challenges),
                  child: Text(
                    'Guarda le challenge',
                    style: texts.titleMedium?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final controller = ref.read(authActionControllerProvider.notifier);
    final email = _email.text.trim();
    final password = _password.text;

    // Il router si accorge da solo del cambio di sessione e porta avanti: qui
    // non c'e' nessuna navigazione da fare a mano.
    if (_signingUp) {
      await controller.signUp(email: email, password: password);
    } else {
      await controller.signIn(email: email, password: password);
    }
  }
}
