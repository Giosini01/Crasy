import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La home: le challenge aperte, una sotto l'altra.
///
/// Non e' una griglia e non sara' mai una griglia. Venti riquadri affiancati
/// sono venti cose fra cui scegliere, e mettono chi guarda nella condizione di
/// scorrere senza fermarsi. Una challenge alla volta, grande quanto lo schermo,
/// e' una cosa sola a cui rispondere si' o no.
class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(liveChallengesProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.palette.accent,
            onRefresh: () async => ref.invalidate(liveChallengesProvider),
            child: CustomScrollView(
              slivers: [
                const _Header(),
                challenges.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, _) => const _Message(
                    title: 'Niente da mostrare',
                    message:
                        'Non riusciamo a caricare le challenge. '
                        'Controlla la connessione e riprova.',
                  ),
                  data: (items) => items.isEmpty
                      ? const _Message(
                          title: 'Nessuna challenge aperta',
                          message:
                              'Appena ne parte una la trovi qui, con quanto '
                              'c\'e\' in palio e quanto tempo hai.',
                        )
                      : _ChallengeList(challenges: items),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page - AppSpacing.xs,
        AppSpacing.xl,
      ),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            const Expanded(child: CrasyWordmark(size: 24)),
            // Creare una challenge sta qui e non in una scheda in fondo: e'
            // una cosa che si fa una volta ogni tanto, non una delle quattro
            // sezioni dell'app.
            IconButton(
              onPressed: () => context.push(AppRoutes.create),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Crea una challenge',
            ),
          ],
        ),
      ),
    );
  }
}

/// Un messaggio al posto delle challenge, con lo stesso margine laterale che
/// avrebbero avuto loro.
class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      sliver: SliverToBoxAdapter(
        child: EmptyState(title: title, message: message),
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  const _ChallengeList({required this.challenges});

  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.section,
      ),
      sliver: SliverList.separated(
        itemCount: challenges.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.section),
        itemBuilder: (context, index) {
          final challenge = challenges[index];

          return ChallengeCard(
            challenge: challenge,
            onOpen: () =>
                context.push(AppRoutes.challengeDetailOf(challenge.id)),
            onParticipate: () =>
                context.push(AppRoutes.participateOf(challenge.id)),
          );
        },
      ),
    );
  }
}
