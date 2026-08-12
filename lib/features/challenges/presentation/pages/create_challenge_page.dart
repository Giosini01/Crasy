import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lanciare una challenge.
///
/// Cinque cose e nient'altro: **quanto si vince, come si chiama, cosa bisogna
/// fare, dove, per quanto tempo**. Sono gli stessi cinque campi che si leggono
/// nella home, nello stesso ordine — chi compila questo modulo sta scrivendo
/// esattamente quello che gli altri vedranno.
///
/// Chi lancia una challenge **non allega nessuna foto**: la faccia della gara
/// la mettono i partecipanti. Ed e' anche chi paga il premio — CRASY non fa da
/// garante, e la schermata lo dice invece di lasciarlo capire dopo.
class CreateChallengePage extends ConsumerStatefulWidget {
  const CreateChallengePage({super.key});

  @override
  ConsumerState<CreateChallengePage> createState() =>
      _CreateChallengePageState();
}

class _CreateChallengePageState extends ConsumerState<CreateChallengePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _brief = TextEditingController();
  final _prize = TextEditingController();
  final _place = TextEditingController();
  final _hours = TextEditingController(text: '24');

  ChallengeScope _scope = ChallengeScope.global;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _brief.dispose();
    _prize.dispose();
    _place.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final creating = ref.watch(createChallengeControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Crea')),
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              Text('LANCIA UNA\nCHALLENGE', style: texts.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Metti un premio, di\' cosa bisogna fare, e guarda cosa si '
                'inventa la gente.',
                style: texts.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Field(
                label: 'Premio in euro',
                controller: _prize,
                hint: '500',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: ChallengeDraftValidators.validatePrize,
              ),
              _Field(
                label: 'Titolo',
                controller: _title,
                hint: 'Do something crazy',
                maxLength: ChallengeDraftValidators.titleMaxLength,
                validator: ChallengeDraftValidators.validateTitle,
              ),
              _Field(
                label: 'La consegna',
                controller: _brief,
                hint: 'Scatta la foto piu\' assurda che riesci a fare oggi.',
                maxLines: 3,
                maxLength: ChallengeDraftValidators.briefMaxLength,
                validator: ChallengeDraftValidators.validateBrief,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionLabel('Dove'),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final scope in ChallengeScope.values)
                    if (scope != ChallengeScope.private)
                      _Choice(
                        label: scope.defaultLabel,
                        selected: _scope == scope,
                        onTap: () => setState(() => _scope = scope),
                      ),
                ],
              ),
              if (_scope == ChallengeScope.local) ...[
                const SizedBox(height: AppSpacing.md),
                _Field(
                  label: 'Citta\'',
                  controller: _place,
                  hint: 'NAPOLI',
                  validator: (value) =>
                      ChallengeDraftValidators.validatePlace(_scope, value),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _Field(
                label: 'Quanto dura — ore (max 24)',
                controller: _hours,
                hint: '24',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                validator: ChallengeDraftValidators.validateHours,
              ),
              // Le scorciatoie riempiono il campo invece di sostituirlo: il
              // valore resta uno solo e sempre visibile, e chi vuole 7 ore le
              // scrive senza cercare una voce che non c'e'.
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final hours in const [1, 3, 6, 12, 24])
                    _Choice(
                      label: '${hours}H',
                      selected: _hours.text == '$hours',
                      onTap: () => setState(() {
                        _hours.text = '$hours';
                      }),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineBanner(message: _error!),
              ],
              const SizedBox(height: AppSpacing.xl),
              CrasyButton(
                label: 'Lancia la challenge',
                loading: creating,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Detto prima, non dopo. E' l'unica riga di questa schermata che
              // parla di soldi veri, e chi la legge deve poterci ripensare
              // mentre ha ancora il dito lontano dal bottone.
              Text(
                'Il premio lo paghi tu. CRASY non fa da garante e non trattiene '
                'i soldi: mettine uno che puoi davvero dare.',
                style: texts.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _error = null);

    final challengeId = await ref
        .read(createChallengeControllerProvider.notifier)
        .create(
          title: _title.text,
          brief: _brief.text,
          prizeEuro: int.parse(_prize.text.trim()),
          scope: _scope,
          place: _place.text,
          hours: int.parse(_hours.text.trim()),
        );

    if (!mounted) {
      return;
    }

    if (challengeId == null) {
      final error = ref.read(createChallengeControllerProvider).error;

      setState(() {
        _error = error == null
            ? 'Non siamo riusciti a lanciarla. Riprova.'
            : ErrorMessageMapper.map(error);
      });

      return;
    }

    // Si atterra sulla challenge appena nata, non sulla home: e' la prova che
    // e' andata a buon fine, e da li' si condivide.
    context.pushReplacement(AppRoutes.challengeDetailOf(challengeId));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.palette.textFaint,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          hintText: hint,
        ),
      ),
    );
  }
}

/// Una scelta fra poche: testo, filetto, e il rosso solo su quella attiva.
class _Choice extends StatelessWidget {
  const _Choice({
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
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.accentTint : null,
          border: Border.all(color: selected ? palette.accent : palette.line),
        ),
        child: Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: selected ? palette.accent : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
