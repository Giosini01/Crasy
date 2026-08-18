import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
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

/// Accende o spegne la fiamma su una partecipazione.
///
/// Sta qui e non dentro i widget perche' la chiamano da tre posti — il doppio
/// tocco sulla foto, il contatore accanto, la griglia dentro una challenge — e
/// **tutti e tre devono passare per la stessa memoria**, altrimenti due gesti
/// sulla stessa foto contano due volte.
Future<VoteOutcome> giveFire(
  BuildContext context,
  WidgetRef ref,
  ChallengeEntry entry, {
  required bool voted,
}) async {
  final pending = ref.read(pendingVoteProvider(entry.id).notifier);

  pending.state = voted;

  final outcome = await ref
      .read(voteControllerProvider)
      .toggle(entry, voted: voted);

  if (outcome != VoteOutcome.done) {
    // Non e' andata: la fiamma torna com'era invece di restare accesa su una
    // promessa non mantenuta.
    pending.state = null;

    if (outcome == VoteOutcome.needsAccount && context.mounted) {
      context.push(AppRoutes.auth);
    }
  }

  return outcome;
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
    final palette = context.palette;
    final voted = ref.watch(entryVotedProvider(entry.id));

    // **Il numero non scende mai sotto zero, ed e' qui che andava messo il
    // freno.**
    //
    // Il conto mostrato e' quello del server piu' una correzione locale, che
    // vale finche' la scrittura e' in volo. Nel mezzo di un mi piace tolto in
    // fretta i due pezzi possono disallinearsi per una frazione di secondo — il
    // contatore e' gia' sceso a zero, l'elenco dei voti dati dice ancora di si'
    // — e la somma dava **-1**. Sul database non c'e' mai stato niente di
    // negativo: era solo il numero disegnato a schermo.
    //
    // Una fiamma negativa non vuol dire niente: nessuno puo' togliere un voto
    // che non ha dato.
    final counted = entry.votes + ref.watch(entryVoteDeltaProvider(entry.id));
    final votes = counted < 0 ? 0 : counted;

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
                '$votes',
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
