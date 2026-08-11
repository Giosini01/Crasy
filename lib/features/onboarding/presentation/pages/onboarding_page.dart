import 'package:app_incontri/core/errors/error_message_mapper.dart';
import 'package:app_incontri/core/services/location_service.dart';
import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:app_incontri/core/widgets/inline_banner.dart';
import 'package:app_incontri/core/widgets/modal_sheet.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:app_incontri/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:app_incontri/features/profile/domain/entities/coordinates.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/presentation/widgets/interests_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _nameController = TextEditingController();
  final _icebreakerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _birthDate;
  GenderIdentity? _gender;
  InterestPreference? _interestedIn;
  Coordinates? _coordinates;
  List<String> _interests = const [];
  bool _locating = false;
  String? _locationError;
  int _step = 0;

  static const int _stepsCount = 6;

  Future<void> _detectLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final coordinates = await ref
          .read(locationServiceProvider)
          .currentApproximateLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _coordinates = coordinates;
        _locating = false;
      });
    } on LocationException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locating = false;
        _locationError = error.message;
      });
    } on Object {
      if (!mounted) {
        return;
      }

      setState(() {
        _locating = false;
        _locationError = 'Non siamo riusciti a leggere la posizione.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _icebreakerController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();

    final selectedDate = await ModalSheet.show<DateTime>(
      context: context,
      builder: (context) => _BirthDateSheet(
        initial: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
        first: DateTime(now.year - 100),
        last: now,
      ),
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _birthDate = selectedDate;
      });
    }
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        return OnboardingValidators.validateName(_nameController.text);
      case 1:
        return OnboardingValidators.validateBirthDate(_birthDate);
      case 2:
        return OnboardingValidators.validateGender(_gender);
      case 3:
        return OnboardingValidators.validateInterest(_interestedIn);
      case 4:
        return OnboardingValidators.validateLocation(_coordinates);
      case 5:
        // Gli interessi sono obbligatori: sono la base dell'affinita', e
        // senza di essi il profilo risulterebbe incompatibile con chiunque.
        return OnboardingValidators.validateInterests(_interests);
    }

    return null;
  }

  Future<void> _goNext() async {
    final validationMessage = _validateCurrentStep();

    if (validationMessage != null) {
      _showValidationError(validationMessage);
      return;
    }

    if (_step < _stepsCount - 1) {
      setState(() {
        _step++;
      });
      return;
    }

    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      _showValidationError('Sessione non valida. Accedi di nuovo.');
      return;
    }

    await ref
        .read(onboardingControllerProvider.notifier)
        .completeOnboarding(
          userId: authState.user.id,
          name: _nameController.text.trim(),
          birthDate: _birthDate!,
          gender: _gender!,
          interestedIn: _interestedIn!,
          coordinates: _coordinates!,
          interests: _interests,
          icebreaker: _icebreakerController.text.trim(),
        );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onboardingAction = ref.watch(onboardingControllerProvider);
    final isLoading = onboardingAction.isLoading;
    final isLastStep = _step == _stepsCount - 1;
    final errorText = onboardingAction.hasError
        ? ErrorMessageMapper.map(onboardingAction.error!)
        : null;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const EyebrowLabel('Il tuo profilo'),
                          Text(
                            '${_step + 1} di $_stepsCount',
                            style: context.texts.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _StepProgress(step: _step, total: _stepsCount),
                      const SizedBox(height: AppSpacing.xxl),
                      Expanded(
                        child: SingleChildScrollView(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.06, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: _OnboardingStepContent(
                                step: _step,
                                nameController: _nameController,
                                birthDate: _birthDate,
                                gender: _gender,
                                interestedIn: _interestedIn,
                                interests: _interests,
                                onInterestsChanged: (value) {
                                  setState(() {
                                    _interests = value;
                                  });
                                },
                                icebreakerController: _icebreakerController,
                                coordinates: _coordinates,
                                locating: _locating,
                                locationError: _locationError,
                                onDetectLocation: _detectLocation,
                                onBirthDateTap: _pickBirthDate,
                                onGenderChanged: (value) {
                                  setState(() {
                                    _gender = value;
                                  });
                                },
                                onInterestedInChanged: (value) {
                                  setState(() {
                                    _interestedIn = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        InlineBanner(message: errorText),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          if (_step > 0) ...[
                            SizedBox(
                              width: 54,
                              height: 54,
                              child: OutlinedButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _step--;
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size.square(54),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _goNext,
                              child: isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: palette.textSecondary,
                                      ),
                                    )
                                  : Text(isLastStep ? 'Completa' : 'Avanti'),
                            ),
                          ),
                        ],
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

/// Barra di avanzamento a segmenti: mostra quanti passi restano, cosa che una
/// barra continua non comunica.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        for (var index = 0; index < total; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xxs + 2),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              height: 5,
              decoration: BoxDecoration(
                color: index <= step ? palette.brand : palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Opzione selezionabile a piena larghezza: bersaglio grande e stato attivo
/// leggibile, al posto delle `ChoiceChip` minute.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.brandTint : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? palette.brand : palette.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.texts.titleMedium?.copyWith(
                  color: selected ? palette.brand : palette.textPrimary,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? palette.brand : palette.border,
            ),
          ],
        ),
      ),
    );
  }
}

/// La data di nascita si sceglie con la ruota di iOS.
///
/// Il calendario di Material, con la sua griglia mensile, per una data di
/// nascita e' scomodo oltre che fuori posto: per arrivare al 1998 servono
/// decine di tocchi, mentre la ruota degli anni ci arriva con un gesto.
class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  late DateTime _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return ModalSheet(
      title: 'Data di nascita',
      onConfirm: () => Navigator.of(context).pop(_selected),
      child: SizedBox(
        height: 260,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: widget.initial,
          minimumDate: widget.first,
          maximumDate: widget.last,
          onDateTimeChanged: (value) => _selected = value,
        ),
      ),
    );
  }
}

/// Rilevamento della posizione.
///
/// La posizione e' obbligatoria perche' senza coordinate il profilo non entra
/// in nessun feed, ma il riquadro spiega anche che cosa viene salvato: la
/// promessa "non la posizione precisa" va mantenuta e resa visibile.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.coordinates,
    required this.locating,
    required this.error,
    required this.onDetect,
  });

  final Coordinates? coordinates;
  final bool locating;
  final String? error;
  final VoidCallback onDetect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final found = coordinates != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: found ? palette.brandTint : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: found ? palette.brand : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                found ? Icons.check_circle_rounded : Icons.my_location_rounded,
                size: 20,
                color: found ? palette.brand : palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  found
                      ? 'Posizione impostata. Salviamo solo la zona, '
                            'arrotondata a circa un chilometro.'
                      : 'Serve per mostrarti chi ti sta vicino.',
                  style: context.texts.bodySmall?.copyWith(
                    color: found ? palette.brand : palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: locating ? null : onDetect,
          icon: locating
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(
            locating
                ? 'Cerco la posizione...'
                : found
                ? 'Aggiorna la posizione'
                : 'Usa la mia posizione',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          InlineBanner(message: error!),
        ],
      ],
    );
  }
}

/// Intestazione comune a ogni passo: titolo grande piu' riga di aiuto.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.texts.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: context.texts.bodyLarge?.copyWith(
          color: context.palette.textSecondary,
        )),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _OnboardingStepContent extends StatelessWidget {
  const _OnboardingStepContent({
    required this.step,
    required this.nameController,
    required this.birthDate,
    required this.gender,
    required this.interestedIn,
    required this.interests,
    required this.onInterestsChanged,
    required this.icebreakerController,
    required this.coordinates,
    required this.locating,
    required this.locationError,
    required this.onDetectLocation,
    required this.onBirthDateTap,
    required this.onGenderChanged,
    required this.onInterestedInChanged,
  });

  final int step;
  final TextEditingController nameController;
  final DateTime? birthDate;
  final GenderIdentity? gender;
  final InterestPreference? interestedIn;
  final List<String> interests;
  final ValueChanged<List<String>> onInterestsChanged;
  final TextEditingController icebreakerController;
  final Coordinates? coordinates;
  final bool locating;
  final String? locationError;
  final VoidCallback onDetectLocation;
  final VoidCallback onBirthDateTap;
  final ValueChanged<GenderIdentity?> onGenderChanged;
  final ValueChanged<InterestPreference?> onInterestedInChanged;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(
              title: 'Come ti chiami?',
              subtitle: 'Usa il nome con cui vuoi farti riconoscere oggi.',
            ),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(
              title: 'Quando sei nato?',
              subtitle: 'Rawsy e riservata ai maggiorenni.',
            ),
            InkWell(
              onTap: onBirthDateTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data di nascita',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(
                  birthDate == null
                      ? 'Seleziona una data'
                      : AppDateUtils.formatItalianDate(birthDate!),
                  style: context.texts.titleMedium?.copyWith(
                    color: birthDate == null
                        ? context.palette.textSecondary
                        : context.palette.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(
              title: 'Come ti identifichi?',
              subtitle: 'Scegli l\'opzione che ti rappresenta meglio.',
            ),
            for (final value in GenderIdentity.values) ...[
              _OptionTile(
                label: value.label,
                selected: gender == value,
                onTap: () => onGenderChanged(value),
              ),
              if (value != GenderIdentity.values.last)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(
              title: 'Chi vuoi conoscere?',
              subtitle: 'Impostiamo solo la preferenza iniziale.',
            ),
            for (final value in InterestPreference.values) ...[
              _OptionTile(
                label: value.label,
                selected: interestedIn == value,
                onTap: () => onInterestedInChanged(value),
              ),
              if (value != InterestPreference.values.last)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(
              title: 'Dove sei?',
              subtitle:
                  'Serve a mostrarti chi ti sta vicino. Salviamo solo una '
                  'zona approssimata, mai la posizione esatta.',
            ),
            _LocationField(
              coordinates: coordinates,
              locating: locating,
              error: locationError,
              onDetect: onDetectLocation,
            ),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(
              title: 'Cosa ti piace fare?',
              subtitle:
                  'Da qui nasce la percentuale di affinita con le persone che '
                  'incontri.',
            ),
            InterestsPicker(
              selected: interests,
              onChanged: onInterestsChanged,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Oggi...', style: context.texts.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Una riga, facoltativa: cosa stai facendo. Da qui partira chi '
              'ti scrive.',
              style: context.texts.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: icebreakerController,
              maxLength: OnboardingValidators.icebreakerMaxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'mi trovi sul divano a riguardare Harry Potter',
              ),
            ),
          ],
        );
    }

    return const SizedBox.shrink();
  }
}
