import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Creare una challenge: la schermata c'e', l'invio no.
///
/// Manca la parte che conta e che non e' codice — chi mette i soldi del premio,
/// chi risponde se il premio non arriva, chi decide che una consegna e'
/// accettabile. Finche' quelle domande non hanno risposta, l'invio resta
/// spento: **un bottone che finge di funzionare e' peggio di un bottone
/// dichiaratamente spento**, perche' il primo lo si scopre dopo aver scritto
/// tutto.
///
/// I campi sono quelli veri e nell'ordine vero, e corrispondono uno a uno a
/// quelli di `Challenge`: quando la creazione si apre, qui cambia il bottone,
/// non la schermata.
class CreateChallengePage extends StatefulWidget {
  const CreateChallengePage({super.key});

  @override
  State<CreateChallengePage> createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  final _title = TextEditingController();
  final _brief = TextEditingController();
  final _prize = TextEditingController();
  final _place = TextEditingController();
  ChallengeScope _scope = ChallengeScope.global;
  int _days = 1;

  @override
  void dispose() {
    _title.dispose();
    _brief.dispose();
    _prize.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Scaffold(
      appBar: AppBar(title: const Text('Crea')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            Text('UNA TUA\nCHALLENGE', style: texts.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Non e\' ancora aperta a tutti: prima dobbiamo sistemare la parte '
              'dei premi. Intanto questo e\' com\'e\' fatta.',
              style: texts.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            _Field(
              label: 'Premio in euro',
              controller: _prize,
              hint: '500',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            _Field(
              label: 'Titolo',
              controller: _title,
              hint: 'Do something crazy',
            ),
            _Field(
              label: 'La consegna',
              controller: _brief,
              hint: 'Scatta la foto piu\' assurda che riesci a fare oggi.',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'DOVE',
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
            const SizedBox(height: AppSpacing.xs),
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
            if (_scope == ChallengeScope.local)
              _Field(label: 'Citta\'', controller: _place, hint: 'NAPOLI'),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'QUANTO DURA',
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final days in const [1, 3, 7])
                  _Choice(
                    label: days == 1 ? '24 ORE' : '$days GIORNI',
                    selected: _days == days,
                    onTap: () => setState(() => _days = days),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const CrasyButton(label: 'Presto disponibile', onPressed: null),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ti avviseremo quando chiunque potra\' lanciare una challenge.',
              style: texts.bodySmall,
            ),
          ],
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
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
