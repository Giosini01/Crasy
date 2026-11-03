import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quanto puo' durare una missione: le stesse caselle nel modulo e qui.
const durateDellaMissione = <(int, String)>[
  (60, '1 ORA'),
  (120, '2 ORE'),
  (180, '3 ORE'),
  (300, '5 ORE'),
  (600, '10 ORE'),
  (1440, '24 ORE'),
];

/// **Si e' sbagliato qualcosa e non ha ancora partecipato nessuno: si corregge.**
///
/// Istantanea invece che archiviata, dieci posti invece di quindici. Prima
/// l'unico modo era cancellarla e rilanciarla, lasciando per strada le spese del
/// pagamento. Titolo e consegna non si toccano: sono passati dal controllo, e un
/// testo nuovo dovrebbe rifarlo. Il premio nemmeno: e' gia' stato pagato.
///
/// Vale il server, che guarda di nuovo: fra l'apertura del foglio e il tocco puo'
/// essere entrato qualcuno, e da li' in poi le regole non si cambiano piu'.
Future<void> mostraModificaMissione(BuildContext context, Challenge challenge) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (_) => ModificaMissione(challenge: challenge),
  );
}

class ModificaMissione extends ConsumerStatefulWidget {
  const ModificaMissione({required this.challenge, super.key});

  final Challenge challenge;

  @override
  ConsumerState<ModificaMissione> createState() => _ModificaMissioneState();
}

class _ModificaMissioneState extends ConsumerState<ModificaMissione> {
  late ChallengeSource _source = widget.challenge.source;
  late MediaKind _mediaKind = widget.challenge.mediaKind;
  late int _posti = widget.challenge.maxParticipants;
  late int _minuti = _durataDi(widget.challenge);

  bool _salvando = false;
  String? _errore;

  static int _durataDi(Challenge challenge) =>
      challenge.endsAt.difference(challenge.startsAt).inMinutes;

  Future<void> _salva() async {
    final prima = widget.challenge;
    final dati = <String, Object?>{
      'challengeId': prima.id,
      if (_source != prima.source) 'source': _source.name,
      if (_mediaKind != prima.mediaKind) 'mediaKind': _mediaKind.name,
      if (_posti != prima.maxParticipants) 'maxParticipants': _posti,
      if (_minuti != _durataDi(prima)) 'minutes': _minuti,
    };

    // Niente di cambiato: non c'e' niente da chiedere al server.
    if (dati.length == 1) {
      Navigator.of(context).pop();

      return;
    }

    setState(() {
      _salvando = true;
      _errore = null;
    });

    try {
      await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable('modificaMissione')
          .call<Object?>(dati);
    } on FirebaseFunctionsException catch (errore) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _errore = errore.message ?? 'Non ci siamo riusciti. Riprova.';
        });
      }

      return;
    } on Object {
      if (mounted) {
        setState(() {
          _salvando = false;
          _errore = 'Non ci siamo riusciti. Riprova.';
        });
      }

      return;
    }

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);

    Navigator.of(context).pop();
    messenger?.showSnackBar(const SnackBar(content: Text('Modificata.')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final posti = {
      ...Challenge.participantCaps,
      if (widget.challenge.maxParticipants > 0)
        widget.challenge.maxParticipants,
    }.toList()..sort();
    final durata = _durataDi(widget.challenge);
    final durate = [
      ...durateDellaMissione,
      // Una durata che non sta fra le caselle, scelta da una versione di prima: resta.
      if (!durateDellaMissione.any((scelta) => scelta.$1 == durata))
        (durata, '$durata MIN'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DisplayTitle('Modifica'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Si può finché non partecipa nessuno. Titolo, consegna e premio '
              'restano quelli.',
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Etichetta('Da dove lo prendono'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final source in ChallengeSource.values)
                  _Scelta(
                    label: source.label,
                    scelta: _source == source,
                    onTap: () => setState(() => _source = source),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Etichetta('Cosa devono mandare'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final kind in MediaKind.values)
                  _Scelta(
                    label: kind.label,
                    scelta: _mediaKind == kind,
                    onTap: () => setState(() => _mediaKind = kind),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Etichetta('Quanti possono partecipare'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final quanti in posti)
                  _Scelta(
                    label: '$quanti',
                    scelta: _posti == quanti,
                    onTap: () => setState(() => _posti = quanti),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Etichetta('Quanto dura, da quando è partita'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final scelta in durate)
                  _Scelta(
                    label: scelta.$2,
                    scelta: _minuti == scelta.$1,
                    onTap: () => setState(() => _minuti = scelta.$1),
                  ),
              ],
            ),
            if (_errore case final errore?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                errore,
                style: texts.bodyMedium?.copyWith(color: palette.accent),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            CrasyButton(label: 'Salva', loading: _salvando, onPressed: _salva),
          ],
        ),
      ),
    );
  }
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        testo.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.palette.textFaint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Scelta extends StatelessWidget {
  const _Scelta({
    required this.label,
    required this.scelta,
    required this.onTap,
  });

  final String label;
  final bool scelta;
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
          color: scelta ? palette.accentTint : null,
          border: Border.all(color: scelta ? palette.accent : palette.line),
        ),
        child: Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: scelta ? palette.accent : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
