import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Una challenge nella home.
///
/// La gerarchia e' tutto qui dentro, e l'ordine non e' casuale: **premio,
/// titolo, consegna, tempo, comando** — poi la vetrina. E' l'ordine in cui uno
/// decide se la cosa lo riguarda: quanto si vince, cosa bisogna fare, quanto
/// tempo resta, come si entra. Solo dopo aver deciso viene voglia di vedere
/// cosa hanno combinato gli altri.
///
/// Non e' una scheda: non c'e' un riquadro, non c'e' un'ombra, non c'e' un
/// fondo diverso. E' un blocco di pagina, e a separarlo dal successivo e' solo
/// dello spazio bianco.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({
    required this.challenge,
    required this.onOpen,
    required this.onParticipate,
    super.key,
  });

  final Challenge challenge;
  final VoidCallback onOpen;
  final VoidCallback onParticipate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final myEntry = ref.watch(myEntryForChallengeProvider(challenge.id));
    final leader = ref.watch(challengeTopEntryProvider(challenge.id));
    final isMine =
        challenge.createdByUserId.isNotEmpty &&
        challenge.createdByUserId == ref.watch(currentUserIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onOpen,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Il premio in rosso, ed e' la cosa piu' grande della
                  // schermata. Se non lo fosse, questa sarebbe un'app di foto
                  // qualunque.
                  Expanded(
                    child: Text(
                      challenge.prizeLabel,
                      style: texts.displayLarge?.copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      challenge.scopeLabel,
                      style: texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(challenge.title.toUpperCase(), style: texts.displayMedium),
              if (challenge.brief.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                // La consegna, non un riassunto: due righe bastano a dire cosa
                // bisogna fare, e chi ne vuole di piu' apre la challenge.
                Text(
                  challenge.brief,
                  style: texts.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              ChallengeMetaRow(challenge: challenge),
              if (challenge.hasCreator) ...[
                const SizedBox(height: AppSpacing.xs),
                ChallengeAuthor(challenge: challenge),
              ],
            ],
          ),
        ),
        if (leader != null) ...[
          const SizedBox(height: AppSpacing.lg),
          ChallengeShowcase(entry: leader, onOpen: onOpen),
        ],
        // Il comando chiude il blocco, sempre. Dopo aver visto cosa sta
        // vincendo si sa cosa bisogna battere, ed e' quello il momento in cui
        // uno decide se partecipare — non prima.
        const SizedBox(height: AppSpacing.md),
        if (isMine)
          const OwnChallengeNote()
        else if (myEntry == null)
          CrasyButton(label: 'Partecipa', onPressed: onParticipate)
        else
          const AlreadyJoinedNote(),
      ],
    );
  }
}

/// La vetrina: la foto in testa alla challenge.
///
/// Una sola, la piu' votata, grande. E' la risposta alla domanda che uno si fa
/// leggendo la consegna — *cosa ci si e' inventato la gente?* — e insieme il
/// metro con cui misurarsi: per vincere bisogna fare meglio di questa.
///
/// Toccandola si entra nella challenge, dove ci sono tutte le altre. Il numero
/// di fiamme sta sopra la foto e non sotto: e' l'unica cosa che va letta
/// insieme all'immagine, non dopo.
class ChallengeShowcase extends StatelessWidget {
  const ChallengeShowcase({
    required this.entry,
    required this.onOpen,
    super.key,
  });

  final ChallengeEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'IN TESTA',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const Spacer(),
              Icon(
                Icons.local_fire_department,
                size: 16,
                color: palette.accent,
              ),
              const SizedBox(width: 2),
              Text(
                '${entry.votes}',
                style: texts.labelMedium?.copyWith(color: palette.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          MediaFrame(url: entry.mediaUrl, caption: entry.authorName),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '@${entry.authorName}',
                  style: texts.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'VEDI TUTTE',
                style: texts.labelSmall?.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: palette.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chi ha lanciato la challenge.
///
/// Con dei soldi in palio, **chi li mette e' un'informazione**, non un dettaglio
/// di cortesia: cambia la fiducia con cui uno decide di partecipare. Le
/// challenge di CRASY portano il nome di CRASY, quelle di una persona il suo.
///
/// C'e' solo il nome e non una foto: i profili altrui non sono leggibili — le
/// regole permettono a ognuno di leggere il proprio e basta — quindi si mostra
/// quello che si ha davvero, invece di un cerchio grigio che finge un ritratto.
class ChallengeAuthor extends StatelessWidget {
  const ChallengeAuthor({required this.challenge, super.key});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final official = challenge.createdByUserId.isEmpty;

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: official ? palette.accentTint : palette.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: official
              ? Icon(
                  Icons.local_fire_department,
                  size: 12,
                  color: palette.accent,
                )
              : Text(
                  challenge.createdByUsername.substring(0, 1).toUpperCase(),
                  style: texts.labelSmall?.copyWith(
                    color: palette.textSecondary,
                    letterSpacing: 0,
                  ),
                ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'Lanciata da @${challenge.createdByUsername}',
            style: texts.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Cosa prende il posto del comando sulle challenge che hai lanciato tu.
///
/// Chi mette il premio non corre per vincerlo. Detto qui invece che con un
/// bottone che poi rifiuta: il limite si spiega prima, non dopo lo scatto.
class OwnChallengeNote extends StatelessWidget {
  const OwnChallengeNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(
          Icons.workspace_premium_outlined,
          size: 16,
          color: palette.textFaint,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'L\'hai lanciata tu — il premio lo metti tu',
            style: context.texts.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Cosa prende il posto del comando quando hai gia' mandato la tua foto.
///
/// Non un bottone spento: un bottone spento invita comunque a premerlo e poi
/// non fa niente. Una riga di testo dice la stessa cosa e non promette nulla.
class AlreadyJoinedNote extends StatelessWidget {
  const AlreadyJoinedNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(Icons.check_rounded, size: 16, color: palette.accent),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Hai gia\' partecipato',
          style: context.texts.labelLarge?.copyWith(color: palette.accent),
        ),
      ],
    );
  }
}

/// La riga di servizio: quanto manca, quanti stanno giocando.
///
/// Un punto medio a separarle e nient'altro. Due icone qui — un orologio e una
/// sagoma — sarebbero due disegni per dire quello che le parole dicono gia'.
class ChallengeMetaRow extends StatelessWidget {
  const ChallengeMetaRow({required this.challenge, super.key});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.texts.labelMedium;
    final ended = challenge.hasEndedAt(DateTime.now());

    return Row(
      children: [
        if (ended)
          Text('chiusa', style: style)
        else
          CountdownText(
            target: challenge.endsAt,
            style: style,
            urgentColor: palette.accent,
          ),
        Text('  ·  ', style: style),
        Text(
          '${challenge.participantsCount} '
          '${challenge.participantsCount == 1 ? 'partecipante' : 'partecipanti'}',
          style: style,
        ),
      ],
    );
  }
}
