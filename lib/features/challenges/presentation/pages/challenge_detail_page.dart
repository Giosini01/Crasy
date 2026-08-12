import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La pagina di una challenge: cosa c'e' in palio, cosa bisogna fare, chi ha
/// gia' mandato qualcosa.
///
/// Il comando per partecipare sta **incollato in fondo allo schermo** e non in
/// coda alla pagina. Le regole e le partecipazioni sono lunghe da scorrere, e
/// un bottone che si raggiunge solo arrivando in fondo e' un bottone che meta'
/// delle persone non vede mai.
class ChallengeDetailPage extends ConsumerWidget {
  const ChallengeDetailPage({required this.challengeId, super.key});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeState = ref.watch(challengeProvider(challengeId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _leave(context)),
        title: const Text('Challenge'),
      ),
      body: AppBackground(
        child: challengeState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const EmptyState(
            title: 'Challenge non disponibile',
            message: 'Non riusciamo a caricarla. Riprova tra poco.',
          ),
          data: (challenge) {
            if (challenge == null) {
              return const EmptyState(
                title: 'Challenge non trovata',
                message: 'Questa challenge non esiste piu\'.',
              );
            }

            return _Body(challenge: challenge);
          },
        ),
      ),
      bottomNavigationBar: challengeState.valueOrNull == null
          ? null
          : _BottomAction(challenge: challengeState.value!),
    );
  }

  /// Chi arriva qui da una notifica o da un link non ha una pagina precedente:
  /// senza questo controllo il tasto indietro non farebbe niente e lascerebbe
  /// la persona bloccata sul dettaglio.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.challenges);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final entries = ref.watch(challengeEntriesProvider(challenge.id));
    final cover = ref.watch(challengeCoverProvider(challenge.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                challenge.prizeLabel,
                style: texts.displayLarge?.copyWith(color: palette.accent),
              ),
            ),
            Text(
              challenge.scopeLabel,
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(challenge.title.toUpperCase(), style: texts.displaySmall),
        if (MediaFrame.hasMedia(cover)) ...[
          const SizedBox(height: AppSpacing.lg),
          MediaFrame(url: cover),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(challenge.brief, style: texts.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        _TimeBlock(challenge: challenge),
        if (challenge.rules.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'REGOLE',
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final rule in challenge.rules)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('—  ', style: texts.bodyMedium),
                  Expanded(child: Text(rule, style: texts.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          challenge.hasEndedAt(DateTime.now())
              ? 'IL VINCITORE'
              : 'PARTECIPAZIONI',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.md),
        entries.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Text(
            'Non riusciamo a caricare le partecipazioni.',
            style: texts.bodyMedium,
          ),
          data: (items) => _Entries(challenge: challenge, entries: items),
        ),
      ],
    );
  }
}

/// Il tempo e i partecipanti, grandi.
///
/// Nella home la stessa informazione sta su una riga di servizio; qui e' una
/// delle cose per cui uno ha aperto la pagina, e prende il corpo che merita.
class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final ended = challenge.hasEndedAt(DateTime.now());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ended ? 'CONCLUSA' : 'TEMPO RIMASTO',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.xxs),
              if (ended)
                Text('—', style: texts.headlineSmall)
              else
                CountdownText(
                  target: challenge.endsAt,
                  style: texts.headlineSmall,
                  urgentColor: palette.accent,
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PARTECIPANTI',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${challenge.participantsCount}',
                style: texts.headlineSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({required this.challenge, required this.entries});

  final Challenge challenge;
  final List<ChallengeEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'Ancora nessuno. Puoi essere il primo.',
        style: context.texts.bodyMedium,
      );
    }

    // A challenge chiusa vince una foto sola, e va vista grande: mostrarla
    // nella stessa griglia da due colonne delle altre significherebbe non
    // proclamare nessuno.
    final winnerId = challenge.winnerEntryId;

    if (winnerId != null) {
      final winner = entries.where((entry) => entry.id == winnerId).firstOrNull;

      if (winner != null) {
        return EntryTile(entry: winner, showChallenge: false);
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.xs,
        mainAxisSpacing: AppSpacing.lg,
        // Il quadrato della foto piu' la riga sotto. Fissato invece che
        // calcolato da un rapporto, cosi' la riga non si schiaccia quando la
        // colonna si stringe.
        mainAxisExtent: 210,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _EntryGridTile(entry: entries[index]),
    );
  }
}

class _EntryGridTile extends StatelessWidget {
  const _EntryGridTile({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MediaFrame(
          url: entry.mediaUrl,
          aspectRatio: 1,
          caption: entry.authorName,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Expanded(
              child: Text(
                '@${entry.authorName}',
                style: context.texts.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            VoteButton(entry: entry),
          ],
        ),
      ],
    );
  }
}

/// Il comando in fondo, sempre visibile.
class _BottomAction extends ConsumerWidget {
  const _BottomAction({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final ended = challenge.hasEndedAt(DateTime.now());
    final myEntry = ref.watch(myEntryForChallengeProvider(challenge.id));

    return Container(
      color: palette.background,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: switch ((ended, myEntry)) {
        (true, _) => ChallengeMetaRow(challenge: challenge),
        (false, final entry?) => Row(
          children: [
            const AlreadyJoinedNote(),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: palette.accent,
                ),
                const SizedBox(width: 4),
                Text('${entry.votes}', style: context.texts.titleMedium),
              ],
            ),
          ],
        ),
        (false, null) => CrasyButton(
          label: 'Partecipa',
          onPressed: () => context.push(AppRoutes.participateOf(challenge.id)),
        ),
      },
    );
  }
}
