import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/media_gestures.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/challenge_closer.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Chi ha vinto.
///
/// E' la schermata che rende vero tutto il resto: se le challenge finiscono e
/// non si vede mai nessuno vincere, il premio in palio resta una promessa.
/// Per questo qui il premio si scrive al passato — **vinti**, non "in palio" —
/// e accanto c'e' il nome di una persona.
class WinnersPage extends ConsumerWidget {
  const WinnersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(endedChallengesProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Il logotipo al posto del titolo. Questa schermata e' la
              // vetrina della promessa — qualcuno ha vinto davvero — ed e' il
              // posto giusto perche' il marchio ci metta la faccia.
              const CrasyHeaderBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  children: [
                    const HighlightedText(
                      'Le challenge chiuse, e chi si è preso i soldi.',
                      highlight: 'chi si è preso i soldi',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    challenges.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const EmptyState(
                        title: 'Non disponibile',
                        message:
                            'Non riusciamo a caricare le challenge concluse. '
                            'Controlla la connessione.',
                      ),
                      data: (items) => _Winners(challenges: items),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le gare finite che vale la pena mostrare.
///
/// **Quelle a cui non ha partecipato nessuno non si vedono.** Una challenge
/// senza foto non ha niente da raccontare: non c'e' un vincitore, non c'e'
/// un'immagine, e resta una riga che dice "non ha partecipato nessuno" in mezzo
/// a chi ha vinto dei soldi. Su una schermata che esiste per rendere credibile
/// la promessa, e' esattamente il contrario di quello che serve.
///
/// Sparire dalla vista non vuol dire sparire dai conti: quelle gare vanno
/// **chiuse lo stesso** — e' cosi' che il premio torna a chi l'aveva messo — e
/// per questo restano qui sotto forma di `_SilentCloser`, che non disegna
/// niente e fa solo quel lavoro. Poco dopo le cancella il server.
class _Winners extends StatelessWidget {
  const _Winners({required this.challenges});

  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    final withPeople = [
      for (final challenge in challenges)
        if (challenge.participantsCount > 0 && challenge.winnerEntryId != '')
          challenge,
    ];
    final empty = [
      for (final challenge in challenges)
        if (!withPeople.contains(challenge)) challenge,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final challenge in empty) _SilentCloser(challenge: challenge),
        if (withPeople.isEmpty)
          const EmptyState(
            title: 'Nessuna challenge conclusa',
            message:
                'Quando la prima challenge si chiude, qui trovi chi ha vinto e '
                'quanto.',
          )
        else
          for (final challenge in withPeople) ...[
            _WinnerBlock(challenge: challenge),
            const SizedBox(height: AppSpacing.section),
          ],
      ],
    );
  }
}

/// Chiude una gara senza partecipanti senza mostrarla.
class _SilentCloser extends ConsumerWidget {
  const _SilentCloser({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesState = ref.watch(challengeEntriesProvider(challenge.id));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(challengeCloserProvider)
          .closeIfNeeded(
            challenge,
            entriesState.valueOrNull ?? const [],
            entriesLoaded: entriesState.hasValue,
          );
    });

    return const SizedBox.shrink();
  }
}

class _WinnerBlock extends ConsumerWidget {
  const _WinnerBlock({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final winnerId = challenge.winnerEntryId;
    final entriesState = ref.watch(challengeEntriesProvider(challenge.id));
    final entries = entriesState.valueOrNull ?? const <ChallengeEntry>[];

    // Se la gara e' scaduta e nessuno l'ha proclamata, la si chiude adesso.
    // Dovrebbe farlo il server; finche' non puo', lo fa la prima schermata che
    // ci passa sopra — vedi `ChallengeCloser`.
    //
    // `hasValue` e' la parte che conta: senza, la prima frame — quando lo
    // stream non ha ancora emesso — proclamava "nessun partecipante".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(challengeCloserProvider)
          .closeIfNeeded(
            challenge,
            entries,
            entriesLoaded: entriesState.hasValue,
          );
    });

    final winner = winnerId == null || winnerId.isEmpty
        ? null
        : entries.where((entry) => entry.id == winnerId).firstOrNull;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.prizeLabel,
                  style: texts.displayMedium?.copyWith(color: palette.accent),
                ),
              ),
              Text(
                challenge.scopeLabel,
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(challenge.title.toUpperCase(), style: texts.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          if (winnerId != null && winnerId.isEmpty)
            Text(
              'Non ha partecipato nessuno. Il premio torna a chi l\'ha messo.',
              style: texts.bodyMedium,
            )
          else if (winner == null)
            Text('Vincitore in arrivo.', style: texts.bodyMedium)
          else ...[
            // **Solo la foto del vincitore.** Le altre stanno dentro la gara,
            // per chi vuole andarle a rivedere; qui si racconta come e' finita,
            // e come e' finita e' una foto sola.
            MediaTap(
              onTap: () => FullscreenMedia.open(
                context,
                entries: [winner],
                entry: winner,
              ),
              child: MediaFrame(
                // A tutta larghezza: l'originale.
                url: winner.mediaUrl,
                video: winner.isVideo,
                aspectRatio: 1,
                caption: winner.authorName,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '@${winner.authorName}',
                    style: texts.titleMedium,
                  ),
                  TextSpan(
                    text: ' ha vinto ${challenge.prizeLabel} con più fiamme',
                    style: texts.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
