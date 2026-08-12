import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:flutter/material.dart';

/// Una challenge nella home.
///
/// La gerarchia e' tutto qui dentro, e l'ordine non e' casuale: **premio,
/// titolo, foto, tempo, comando**. Chi scorre deve capire in due secondi quanto
/// puo' vincere, cosa deve fare e quanto tempo gli resta — in quest'ordine,
/// perche' e' l'ordine in cui uno decide se la cosa lo riguarda.
///
/// Non e' una scheda: non c'e' un riquadro, non c'e' un'ombra, non c'e' un
/// fondo diverso. E' un blocco di pagina, e a separarlo dal successivo e' solo
/// dello spazio bianco. Con l'immagine in proporzione 4:5 ne entra circa uno per
/// schermata, ed e' voluto — cosi' il bottone rosso resta uno solo alla volta.
class ChallengeCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
              const SizedBox(height: AppSpacing.lg),
              // Senza didascalia: il titolo sta gia' qui sopra, e ripeterlo
              // dentro il riquadro della foto mancante lo scrive due volte a
              // due centimetri di distanza.
              MediaFrame(url: challenge.coverUrl),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ChallengeMetaRow(challenge: challenge),
        const SizedBox(height: AppSpacing.md),
        CrasyButton(label: 'Partecipa', onPressed: onParticipate),
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
