import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/fire_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Una partecipazione nel feed: la foto, chi l'ha mandata, il voto.
///
/// La foto occupa tutta la larghezza e tutto il resto sta su una riga sola
/// sotto di essa. Il contenuto e' la cosa folle; l'interfaccia attorno deve
/// essere cosi' silenziosa da non farsi notare.
class EntryTile extends ConsumerWidget {
  const EntryTile({required this.entry, this.showChallenge = true, super.key});

  final ChallengeEntry entry;

  /// Il titolo della challenge si mostra nel feed, dove le foto arrivano da
  /// challenge diverse. Dentro una challenge sola sarebbe la stessa riga
  /// ripetuta sotto ogni foto.
  final bool showChallenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final createdAt = entry.createdAt;
    final voted =
        ref.watch(votedEntryIdsProvider).valueOrNull?.contains(entry.id) ??
        false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FireTap(
          voted: voted,
          onFire: () => giveFire(context, ref, entry, voted: true),
          child: MediaFrame(url: entry.mediaUrl, caption: entry.authorName),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${entry.authorName}',
                          style: texts.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isWinner) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'VINCITORE',
                          style: texts.labelSmall?.copyWith(
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showChallenge && entry.challengeTitle.isNotEmpty)
                    Text(
                      entry.challengeTitle.toUpperCase() +
                          (createdAt == null
                              ? ''
                              : '  ·  ${AppDateUtils.shortTimeAgo(createdAt)}'),
                      style: texts.labelMedium?.copyWith(
                        color: palette.textFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            VoteButton(entry: entry),
          ],
        ),
      ],
    );
  }
}

/// Accende o spegne la fiamma su una partecipazione.
///
/// Sta qui e non dentro i widget perche' la chiamano in tre posti — la foto nel
/// feed, il contatore accanto, la griglia dentro una challenge — e la parte che
/// non va duplicata e' cosa fare quando il voto **non** si puo' dare: mandare
/// alla registrazione, o non fare niente se e' la propria foto.
Future<VoteOutcome> giveFire(
  BuildContext context,
  WidgetRef ref,
  ChallengeEntry entry, {
  required bool voted,
}) async {
  final outcome = await ref
      .read(voteControllerProvider)
      .toggle(entry, voted: voted);

  if (outcome == VoteOutcome.needsAccount && context.mounted) {
    context.push(AppRoutes.auth);
  }

  return outcome;
}

/// La fiamma e il suo numero.
///
/// Tocco singolo: accende se e' spenta, spegne se e' accesa. E' l'unico
/// comando dell'app che fa due cose opposte, e va bene cosi': e' il gesto che
/// tutti si aspettano da un "mi piace".
///
/// Il colore **non aspetta il server**. Al tocco la fiamma diventa subito
/// rossa, e resta cosi' finche' lo stream non conferma; se la scrittura non va
/// a buon fine torna com'era. Senza questo, fra il tocco e il viaggio di andata
/// e ritorno su Firestore c'e' un momento in cui non succede niente — e in quel
/// momento la gente tocca una seconda volta, disfacendo quello che aveva appena
/// fatto.
///
/// Non e' un cuore e non e' un pollice. Un cuore su una foto di una persona
/// vuol dire una cosa sola, ed e' esattamente la cosa che CRASY non e'; un
/// pollice in su e' il gesto di un sondaggio. La fiamma dice quello che va
/// detto — **questa e' fuori di testa** — ed e' lo stesso segno che il marchio
/// porta addosso.
///
/// La foto con piu' fiamme allo scadere del tempo si prende il premio, quindi
/// questo e' letteralmente il bottone che decide chi vince.
class VoteButton extends ConsumerStatefulWidget {
  /// La chiave e' l'identificativo della partecipazione, e **non e' opzionale**.
  ///
  /// Senza, dentro una lista che si riordina — e questa si riordina a ogni
  /// fiamma, perche' e' ordinata per fiamme — Flutter riusa lo stato di un
  /// elemento su un altro. Il risultato era una fiamma accesa sulla foto
  /// sbagliata: si votava la prima e si vedeva colorarsi la seconda.
  VoteButton({required this.entry}) : super(key: ValueKey(entry.id));

  final ChallengeEntry entry;

  @override
  ConsumerState<VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends ConsumerState<VoteButton> {
  /// Quello che l'utente ha appena chiesto, finche' lo stream non lo conferma.
  bool? _pending;

  @override
  void didUpdateWidget(VoteButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Cintura oltre alle bretelle: se per qualunque motivo questo stato
    // finisse su un'altra foto, l'attesa della precedente non deve seguirlo.
    if (oldWidget.entry.id != widget.entry.id) {
      _pending = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entry = widget.entry;
    final confirmed =
        ref.watch(votedEntryIdsProvider).valueOrNull?.contains(entry.id) ??
        false;

    // Quando la realta' raggiunge l'attesa, l'attesa non serve piu'.
    if (_pending == confirmed) {
      _pending = null;
    }

    final voted = _pending ?? confirmed;

    return Semantics(
      button: true,
      label: voted ? 'Togli la fiamma' : 'Dai la fiamma',
      child: InkWell(
        onTap: () => _toggle(voted: !voted),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                voted
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                size: 20,
                color: voted ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.votes}',
                style: context.texts.titleMedium?.copyWith(
                  color: voted ? palette.accent : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle({required bool voted}) async {
    setState(() => _pending = voted);

    final outcome = await giveFire(context, ref, widget.entry, voted: voted);

    // Se non e' andata — serve un account, o e' la propria foto — la fiamma
    // torna com'era invece di restare accesa su una promessa non mantenuta.
    if (outcome != VoteOutcome.done && mounted) {
      setState(() => _pending = null);
    }
  }
}
