import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/recent_winners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Com'è finita: le gare chiuse, con la foto che ha vinto.**
///
/// Ha cambiato posto due volte prima di avere il suo. E' nata come terza scheda
/// dentro la tendenza, accanto alle classifiche, dove la guardava soltanto chi
/// era già convinto; poi e' finita in fondo alla home, che sembrava meglio —
/// sotto gli occhi di chi sta decidendo — e invece arrivava **dopo** tutte le
/// gare aperte, cioe' dopo che uno aveva gia' deciso.
///
/// Il problema era lo stesso tutte e due le volte: questa roba stava
/// appoggiata dentro una schermata che parlava d'altro. Ha una cosa sola da
/// dire, e' la piu' importante che l'app abbia da dire — **qui si vince
/// davvero** — e una cosa cosi' non si mette in coda a un'altra. Si apre.
class RecentlyEndedPage extends ConsumerWidget {
  const RecentlyEndedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(endedChallengesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Appena finite'),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
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
                data: (items) => RecentWinners(challenges: items),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
