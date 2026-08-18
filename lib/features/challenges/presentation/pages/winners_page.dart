import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              // Il logotipo al posto del titolo. Questa schermata e' la
              // vetrina della promessa — qualcuno ha vinto davvero — ed e' il
              // posto giusto perche' il marchio ci metta la faccia.
              const CrasyHeader(),
              const SizedBox(height: AppSpacing.lg),
              const HighlightedText(
                'Le challenge chiuse, e chi si e\' preso i soldi.',
                highlight: 'chi si e\' preso i soldi',
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
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        title: 'Nessuna challenge conclusa',
                        message:
                            'Quando la prima challenge si chiude, qui trovi chi '
                            'ha vinto e quanto.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final challenge in items) ...[
                            _WinnerBlock(challenge: challenge),
                            const SizedBox(height: AppSpacing.section),
                          ],
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

class _WinnerBlock extends ConsumerWidget {
  const _WinnerBlock({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final winnerId = challenge.winnerEntryId;

    // Le partecipazioni si leggono solo se un vincitore c'e' davvero: una
    // challenge chiusa senza proclamazione non deve costare una query.
    final winner = winnerId == null
        ? null
        : ref
              .watch(challengeEntriesProvider(challenge.id))
              .valueOrNull
              ?.where((entry) => entry.id == winnerId)
              .firstOrNull;

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
          if (winner == null)
            Text('Vincitore in arrivo.', style: texts.bodyMedium)
          else ...[
            MediaFrame(
              url: winner.mediaUrl,
              aspectRatio: 1,
              caption: winner.authorName,
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
                    text: ' ha vinto ${challenge.prizeLabel}',
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
