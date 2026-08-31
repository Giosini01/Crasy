import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/fire_tap.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Una partecipazione: la foto, chi l'ha mandata, la fiamma.
///
/// La foto occupa tutta la larghezza e tutto il resto sta su una riga sola
/// sotto di essa. Il contenuto e' la cosa folle; l'interfaccia attorno deve
/// essere cosi' silenziosa da non farsi notare.
class EntryTile extends ConsumerWidget {
  const EntryTile({
    required this.entry,
    this.showChallenge = true,
    this.siblings,
    super.key,
  });

  final ChallengeEntry entry;

  /// Le altre partecipazioni della stessa gara, se ce ne sono.
  ///
  /// Servono solo per scorrere a schermo intero: senza, la foto si apre lo
  /// stesso e resta da sola.
  final List<ChallengeEntry>? siblings;

  /// Il titolo della challenge si mostra dove le foto arrivano da challenge
  /// diverse. Dentro una challenge sola sarebbe la stessa riga ripetuta sotto
  /// ogni foto.
  final bool showChallenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final createdAt = entry.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FireTap(
          entry: entry,
          onTap: () => FullscreenMedia.open(
            context,
            entries: siblings ?? [entry],
            entry: entry,
          ),
          child: MediaFrame(
            url: entry.mediaUrl,
            video: entry.isVideo,
            caption: entry.authorName,
            mine: entry.userId == ref.watch(currentUserIdProvider),
            // La propria foto in attesa si vede, con scritto che e' in coda:
            // sapere che sta per essere controllata e' molto meglio che vederla
            // sparire senza spiegazioni.
            overlay: entry.moderation == EntryModeration.pending
                ? const _PendingOverlay()
                : null,
          ),
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
                        // Il nome porta al profilo di chi ha mandato la foto:
                        // e' il modo piu' naturale di incontrare qualcuno qui
                        // dentro — prima si vede cosa ha fatto, poi chi e'.
                        child: GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.userProfileOf(entry.userId),
                          ),
                          child: Text(
                            '@${entry.authorName}',
                            style: texts.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
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

/// La fiamma e il suo numero.
///
/// Tocco singolo: accende se e' spenta, spegne se e' accesa. E' l'unico comando
/// dell'app che fa due cose opposte, e va bene cosi': e' il gesto che tutti si
/// aspettano da un "mi piace".
///
/// Colore e numero **non aspettano il server**: cambiano al tocco e restano
/// cosi' finche' lo stream non conferma. Senza, fra il tocco e il viaggio di
/// andata e ritorno su Firestore c'e' un momento in cui non succede niente — e
/// in quel momento la gente tocca una seconda volta.
class VoteButton extends ConsumerWidget {
  const VoteButton({required this.entry, super.key});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voted = ref.watch(entryVotedProvider(entry.voteKey));
    final live = ref.watch(challengeIsLiveProvider(entry.challengeId));
    // Finite le tre fiamme, quelle spente si smorzano: si vede che non si puo'
    // piu', senza toglierle di mezzo. Restano toccabili apposta — un comando
    // morto non spiega niente, e chi lo tocca si sente dire perche'.
    final spendibile =
        voted || ref.watch(firesLeftProvider(entry.challengeId)) > 0;

    // Il numero lo decide `visibleVotes`: o la richiesta in corso, o il
    // server, mai i due sommati. Vedi `VoteIntents`.
    final votes = visibleVotes(ref, entry);

    // **A gara finita non e' piu' un comando.** Niente tocco, niente
    // etichetta che promette qualcosa: resta il conto com'era all'ultimo
    // secondo, e la fiamma rossa di chi l'aveva data.
    if (!live) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: _Fire(voted: voted, votes: votes),
      );
    }

    return Semantics(
      button: true,
      label: voted ? 'Togli la fiamma' : 'Dai la fiamma',
      child: InkWell(
        onTap: () => giveFire(context, ref, entry, voted: !voted),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: _Fire(voted: voted, votes: votes, dimmed: !spendibile),
        ),
      ),
    );
  }
}

/// La fiamma e il numero, disegnati.
///
/// Sta in un widget suo perche' li' e' l'unico posto in cui esiste: a gara
/// aperta ci si tocca sopra, a gara finita no, ma **quello che si vede e' lo
/// stesso** — la fiamma non deve cambiare aspetto quando smette di essere un
/// comando, o sembrerebbe che sia successo qualcosa ai voti.
class _Fire extends StatelessWidget {
  const _Fire({required this.voted, required this.votes, this.dimmed = false});

  final bool voted;

  /// Quante fiamme ha preso, **oppure niente**.
  ///
  /// Nullo vuol dire "a gara aperta non si dice": al posto del numero c'e' un
  /// trattino. Vedi `visibleVotes`.
  final int? votes;

  /// Vero quando le fiamme di questa gara sono finite: la si vede piu' pallida.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = voted
        ? palette.accent
        : (dimmed ? palette.textFaint : palette.textSecondary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          voted
              ? Icons.local_fire_department
              : Icons.local_fire_department_outlined,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          votesLabel(votes),
          style: context.texts.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Il velo su una foto che il controllo non ha ancora guardato.
///
/// La vede **solo chi l'ha mandata**: per tutti gli altri quella foto ancora non
/// esiste. Dirglielo con una parola sopra l'immagine e' l'unico modo perche' non
/// pensi che l'invio sia fallito.
class _PendingOverlay extends StatelessWidget {
  const _PendingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x59000000),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          color: const Color(0xCC000000),
          child: const Text(
            'IN VERIFICA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
