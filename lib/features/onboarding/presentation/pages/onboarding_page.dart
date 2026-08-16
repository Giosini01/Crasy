import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/moderation/age_policy.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:crasy/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

  DateTime? _birthDate;
  String? _birthDateError;
  Uint8List? _photo;
  String? _photoContentType;

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
                Center(
                  child: _PhotoPicker(photo: _photo, onPick: _pickPhoto),
                ),
                const SizedBox(height: AppSpacing.xl),
                const DisplayTitle('COME TI\nCHIAMANO'),
                const SizedBox(height: AppSpacing.xs),
                const HighlightedText(
                  'E\' il nome che sta sotto ogni foto che mandi. Minuscolo, '
                  'senza spazi.',
                  highlight: 'sotto ogni foto che mandi',
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
                const SizedBox(height: AppSpacing.lg),
                _BirthDateField(
                  value: _birthDate,
                  error: _birthDateError,
                  onPick: _pickBirthDate,
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

  /// La foto profilo, scelta subito.
  ///
  /// **Dalla galleria si puo'**, a differenza delle challenge: la foto profilo
  /// non e' una gara, e obbligare a farsi un selfie per registrarsi sarebbe una
  /// regola senza motivo.
  ///
  /// Resta facoltativa. Chi non la mette entra lo stesso con le sue iniziali —
  /// una foto in piu' fra la registrazione e la prima challenge e' una persona
  /// in meno che ci arriva.
  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Finisce in un cerchio da settantasei punti: ventimila pixel di lato
      // sarebbero venti megabyte per niente.
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
    );

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _photo = bytes;
      _photoContentType = picked.mimeType;
    });
  }

  /// Il selettore della data parte gia' fermo alla soglia dei diciotto anni.
  ///
  /// `lastDate` e' l'ultima data che risulta maggiorenne oggi: chi e' minorenne
  /// **non riesce nemmeno a scegliere** una data che poi verrebbe rifiutata. Un
  /// limite che si vede prima e' molto meglio di un errore che arriva dopo.
  Future<void> _pickBirthDate() async {
    final latest = AgePolicy.latestAdultBirthDate();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(latest.year - 7, latest.month, latest.day),
      firstDate: DateTime(1920),
      lastDate: latest,
      helpText: 'QUANDO SEI NATO',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _birthDate = picked;
      _birthDateError = AgePolicy.validate(picked);
    });
  }

  Future<void> _submit() async {
    final ageError = AgePolicy.validate(_birthDate);

    if (ageError != null) {
      setState(() => _birthDateError = ageError);
    }

    if (!(_formKey.currentState?.validate() ?? false) || ageError != null) {
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
          birthDate: _birthDate!,
          bio: _bio.text,
          city: _city.text,
          photo: _photo,
          photoContentType: _photoContentType,
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

/// La data di nascita.
///
/// Non e' un campo di testo: una data scritta a mano si sbaglia, e in un
/// controllo sull'eta' un refuso vuol dire far entrare qualcuno che non doveva.
/// Si tocca e si sceglie da un calendario che oltre la soglia non arriva.
class _BirthDateField extends StatelessWidget {
  const _BirthDateField({
    required this.value,
    required this.error,
    required this.onPick,
  });

  final DateTime? value;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUANDO SEI NATO',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: onPick,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: error == null ? palette.line : palette.danger,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null
                        ? 'Tocca per scegliere'
                        : AppDateUtils.formatItalianDate(value!),
                    style: value == null
                        ? texts.bodyLarge?.copyWith(color: palette.textFaint)
                        : texts.bodyLarge,
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: palette.textFaint,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          error ??
              'Su CRASY si entra da maggiorenni: girano soldi veri e si chiede '
                  'di uscire a fare qualcosa per vincerli.',
          style: texts.bodySmall?.copyWith(
            color: error == null ? palette.textSecondary : palette.danger,
          ),
        ),
      ],
    );
  }
}

/// La foto profilo nell'onboarding: un cerchio che si tocca.
///
/// Vuoto mostra una macchina fotografica e la parola "facoltativa", cosi' non
/// sembra un campo obbligatorio da riempire prima di andare avanti. Pieno mostra
/// la foto e un segno per cambiarla.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.onPick});

  final Uint8List? photo;
  final VoidCallback onPick;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chosen = photo;

    return GestureDetector(
      onTap: onPick,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: chosen == null
                        ? ColoredBox(
                            color: palette.surfaceMuted,
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 26,
                              color: palette.textFaint,
                            ),
                          )
                        : Image.memory(chosen, fit: BoxFit.cover),
                  ),
                ),
                if (chosen != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: palette.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.line),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            chosen == null ? 'FOTO — FACOLTATIVA' : 'CAMBIA FOTO',
            style: context.texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
        ],
      ),
    );
  }
}
