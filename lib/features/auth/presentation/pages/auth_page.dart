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

/// Entrare in CRASY.
///
/// Email e password, e basta. **E' la prima cosa che si vede aprendo l'app**:
/// da fuori non si guarda niente, perche' qui girano soldi veri, si vota chi li
/// vince e si entra da maggiorenni. Nessuna delle tre cose regge se chi guarda
/// non ha un nome.
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
  bool _passwordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const CrasyWordmark(),
                const SizedBox(height: AppSpacing.xxl),
                DisplayTitle(
                  _signingUp ? 'CREA IL TUO\nACCOUNT' : 'BENTORNATO',
                ),
                const SizedBox(height: AppSpacing.xs),
                if (_signingUp)
                  const HighlightedText(
                    'Ti serve per partecipare alle challenge e per ricevere i '
                    'premi che vinci.',
                    highlight: 'premi che vinci',
                  )
                else
                  Text(
                    'Entra e riprendi da dove avevi lasciato.',
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
                  obscureText: !_passwordVisible,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: AuthValidators.validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'PASSWORD',
                    hintText: 'almeno 8 caratteri',
                    // Mostrare la password e' quasi obbligatorio su un telefono:
                    // otto caratteri battuti al buio su una tastiera piccola si
                    // sbagliano, e chi sbaglia non capisce perche' non entra.
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      tooltip: _passwordVisible
                          ? 'Nascondi la password'
                          : 'Mostra la password',
                    ),
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
