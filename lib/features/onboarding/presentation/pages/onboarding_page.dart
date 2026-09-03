import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/moderation/age_policy.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/birth_date_picker.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:crasy/features/onboarding/presentation/providers/username_check.dart';
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

  /// Quello che c'e' scritto adesso nel campo del nome.
  ///
  /// Sta qui e non si legge dal controller perche' serve a **ricostruire**: il
  /// segno di spunta e i suggerimenti dipendono da questo, e un controller non
  /// avvisa nessuno quando cambia.
  String _digitato = '';

  DateTime? _birthDate;
  String? _birthDateError;
  Uint8List? _photo;
  String? _photoContentType;

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  onChanged: (valore) =>
                      setState(() => _digitato = valore.trim().toLowerCase()),
                  decoration: InputDecoration(
                    prefixText: '@',
                    labelText: 'NOME UTENTE',
                    hintText: 'martina',
                    // **La risposta arriva mentre si scrive, non al salvataggio.**
                    // Scoprire che il nome e' preso dopo aver riempito tutto il
                    // resto vuol dire tornare su, cancellare, inventare e
                    // ricontrollare — e a quel punto molti chiudono l'app.
                    suffixIcon: _UsernameMark(username: _digitato),
                  ),
                ),
                _UsernameHint(
                  username: _digitato,
                  onPick: (scelto) {
                    _username.text = scelto;
                    setState(() => _digitato = scelto);
                  },
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
                  // Era il penultimo campo e ora e' l'ultimo: il tasto della
                  // tastiera deve dire "fatto", non "avanti" verso niente.
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  maxLength: OnboardingValidators.bioMaxLength,
                  validator: OnboardingValidators.validateBio,
                  decoration: const InputDecoration(
                    labelText: 'UNA RIGA SU DI TE — FACOLTATIVA',
                    hintText: 'Faccio cose assurde.',
                  ),
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

  /// Il selettore della data, quello del telefono su cui l'app sta girando.
  ///
  /// **Si apriva su una data gia' maggiorenne**, e bastava confermare senza
  /// toccare niente per registrarsi con un'eta' che nessuno aveva dichiarato:
  /// un muro che si passa premendo due volte "fatto" non e' un muro. Adesso non
  /// c'e' niente di preselezionato — i dettagli stanno in `pickBirthDate`.
  Future<void> _pickBirthDate() async {
    final picked = await pickBirthDate(context, current: _birthDate);

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

/// Il segno accanto al nome: spunta se e' libero, croce se e' di qualcuno.
///
/// **Niente durante l'attesa se non un filo che gira.** Un segno rosso mostrato
/// mentre la risposta e' ancora in viaggio dice una cosa falsa per mezzo
/// secondo, e mezzo secondo basta a far cancellare un nome che andava bene.
class _UsernameMark extends ConsumerWidget {
  const _UsernameMark({required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    // Sotto il minimo non si chiede niente: il campo ha gia' il suo errore, e
    // due segnalazioni diverse sulla stessa riga si contraddicono.
    if (OnboardingValidators.validateUsername(username) != null) {
      return const SizedBox.shrink();
    }

    return ref
        .watch(usernameCheckProvider(username))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          // Se la lettura non riesce non si dice ne' si' ne' no: il nome verra'
          // controllato comunque al salvataggio, e una croce per un problema di
          // rete accusa la persona sbagliata.
          error: (_, _) => const SizedBox.shrink(),
          data: (esito) => Icon(
            esito.free ? Icons.check_rounded : Icons.close_rounded,
            color: esito.free ? const Color(0xFF1B9E4B) : palette.accent,
          ),
        );
  }
}

/// Quando il nome e' preso: tre alternative da toccare.
class _UsernameHint extends ConsumerWidget {
  const _UsernameHint({required this.username, required this.onPick});

  final String username;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (OnboardingValidators.validateUsername(username) != null) {
      return const SizedBox.shrink();
    }

    final esito = ref.watch(usernameCheckProvider(username)).valueOrNull;

    if (esito == null || esito.free) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gia\' preso.',
            style: texts.bodySmall?.copyWith(color: palette.accent),
          ),
          if (esito.suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final proposta in esito.suggestions)
                  GestureDetector(
                    onTap: () => onPick(proposta),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accentTint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '@$proposta',
                        style: texts.bodySmall?.copyWith(color: palette.accent),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
