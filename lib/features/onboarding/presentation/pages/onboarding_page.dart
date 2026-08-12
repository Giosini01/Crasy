import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:crasy/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'onboarding: una schermata, un campo obbligatorio.
///
/// Chi arriva qui ha appena creato l'account e vuole vedere le challenge. Ogni
/// domanda in piu' fra qui e la prima foto e' una persona che non ci arriva —
/// quindi si chiede il nome con cui firmera' le sue partecipazioni, e le altre
/// due cose sono facoltative e dichiarate tali.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;
    final state = ref.watch(onboardingControllerProvider);
    final error = state.error;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xxl,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                Text('COME TI\nCHIAMANO', style: texts.displaySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'E\' il nome che sta sotto ogni foto che mandi. Minuscolo, '
                  'senza spazi.',
                  style: texts.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _username,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  maxLength: OnboardingValidators.usernameMaxLength,
                  validator: OnboardingValidators.validateUsername,
                  // La minuscola e' imposta mentre si scrive invece di essere
                  // corretta dopo: vedersi cambiare il nome al momento del
                  // salvataggio e' peggio che non poterlo scrivere maiuscolo.
                  inputFormatters: [_LowercaseFormatter()],
                  decoration: const InputDecoration(
                    prefixText: '@',
                    labelText: 'NOME UTENTE',
                    hintText: 'martina',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bio,
                  textInputAction: TextInputAction.next,
                  maxLength: OnboardingValidators.bioMaxLength,
                  validator: OnboardingValidators.validateBio,
                  decoration: const InputDecoration(
                    labelText: 'UNA RIGA SU DI TE — FACOLTATIVA',
                    hintText: 'Faccio cose assurde.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _city,
                  textInputAction: TextInputAction.done,
                  maxLength: OnboardingValidators.cityMaxLength,
                  validator: OnboardingValidators.validateCity,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'CITTA\' — FACOLTATIVA',
                    hintText: 'Napoli',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'La citta\' serve solo a farti trovare le challenge locali.',
                  style: texts.bodySmall,
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  InlineBanner(message: ErrorMessageMapper.map(error)),
                ],
                const SizedBox(height: AppSpacing.xl),
                CrasyButton(
                  label: 'Entra in Crasy',
                  loading: state.isLoading,
                  onPressed: _submit,
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

    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      return;
    }

    await ref
        .read(onboardingControllerProvider.notifier)
        .completeOnboarding(
          userId: authState.user.id,
          username: _username.text,
          bio: _bio.text,
          city: _city.text,
        );
  }
}

/// Tiene il nome utente in minuscolo mentre si digita.
class _LowercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
