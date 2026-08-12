import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Una challenge nella home.
///
/// La gerarchia e' tutto qui dentro, e l'ordine non e' casuale: **premio,
/// titolo, foto, tempo, comando**. Chi scorre deve capire in due secondi quanto
/// puo' vincere, cosa deve fare e quanto tempo gli resta — in quest'ordine,
/// perche' e' l'ordine in cui uno decide se la cosa lo riguarda.
///
/// Non e' una scheda: non c'e' un riquadro, non c'e' un'ombra, non c'e' un
/// fondo diverso. E' un blocco di pagina, e a separarlo dal successivo e' solo
/// dello spazio bianco.
///
/// La foto compare **solo se esiste**: una challenge appena aperta, a cui non ha
/// ancora partecipato nessuno, e' tre righe di testo e un bottone. Appena arriva
/// la prima partecipazione, quella foto diventa la faccia della gara.
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
    final cover = ref.watch(challengeCoverProvider(challenge.id));
    final myEntry = ref.watch(myEntryForChallengeProvider(challenge.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Il premio in rosso, ed e' la cosa piu' grande della schermata.
            // Se non lo fosse, questa sarebbe un'app di foto qualunque.
            Expanded(
              child: Text(
                challenge.prizeLabel,
                style: texts.displayLarge?.copyWith(color: palette.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                challenge.scopeLabel,
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: onOpen,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(challenge.title.toUpperCase(), style: texts.displayMedium),
              if (MediaFrame.hasMedia(cover)) ...[
                const SizedBox(height: AppSpacing.lg),
                MediaFrame(url: cover),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ChallengeMetaRow(challenge: challenge),
        const SizedBox(height: AppSpacing.md),
        if (myEntry == null)
          CrasyButton(label: 'Partecipa', onPressed: onParticipate)
        else
          const AlreadyJoinedNote(),
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
