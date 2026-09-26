import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/suggested_friend_row.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Chi conosci gia' qui. Si vede una volta, appena finito di iscriversi.**
///
/// E' il momento giusto e non ce n'e' un altro: uno ha appena messo il numero,
/// ha letto le regole, e quello che sta per trovarsi davanti e' un elenco di
/// gare fra sconosciuti. Un'app di sfide fra amici senza un amico e' una cosa
/// che si chiude e non si riapre.
///
/// **Si salta.** La scritta in alto a destra e' piccola ma c'e', e non e' una
/// concessione: il permesso sui contatti lo da' il sistema operativo, e una
/// schermata senza uscita che lo pretende non supera la revisione di Apple.
/// Quello che si puo' fare e' passare di qui, spiegare bene, e chiedere una
/// volta sola.
class WhoYouKnowPage extends ConsumerStatefulWidget {
  const WhoYouKnowPage({super.key});

  @override
  ConsumerState<WhoYouKnowPage> createState() => _WhoYouKnowPageState();
}

class _WhoYouKnowPageState extends ConsumerState<WhoYouKnowPage> {
  bool _chiudendo = false;

  /// Segna che e' stata vista e lascia andare avanti il muro.
  ///
  /// Se la scrittura non riesce si entra lo stesso: il peggio che puo'
  /// succedere e' rivedere questa schermata al prossimo avvio, mentre tenere
  /// qualcuno fuori dall'app perche' non siamo riusciti a segnare una
  /// casellina sarebbe molto peggio.
  Future<void> _vaiAvanti() async {
    final sessione = ref.read(authStateProvider);

    if (sessione is! AuthenticatedAuthState || _chiudendo) {
      return;
    }

    setState(() => _chiudendo = true);

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .markContactsPromptSeen(sessione.user.id);
    } on Object {
      if (mounted) {
        setState(() => _chiudendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final stato = ref.watch(suggestedFriendsProvider);
    final trovati = stato.valueOrNull;
    final negato = stato.hasError && stato.error is ContattiNegati;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _chiudendo ? null : _vaiAvanti,
                  child: Text(
                    'Salta',
                    style: texts.bodyMedium?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text.rich(
                      TextSpan(
                        style: texts.headlineMedium,
                        children: [
                          const TextSpan(text: 'CHI CONOSCI\n'),
                          TextSpan(
                            text: 'GIÀ QUI',
                            style: TextStyle(color: palette.accent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      trovati == null
                          ? 'Guardiamo se qualcuno dei tuoi contatti ha già '
                                'CRASY. Dal telefono escono solo i numeri, mai '
                                'i nomi, e di chi non è iscritto non resta '
                                'niente da nessuna parte.'
                          : trovati.isEmpty
                          ? 'Nessuno dei tuoi contatti è ancora qui. Capita '
                                'presto: CRASY è appena partita.'
                          : 'Queste persone ce le hai in rubrica.',
                      style: texts.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
              Expanded(
                child: _Corpo(
                  stato: stato,
                  negato: negato,
                  onCerca: () =>
                      ref.read(suggestedFriendsProvider.notifier).cerca(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _chiudendo
                        ? null
                        : trovati == null && !negato
                        ? () => ref
                              .read(suggestedFriendsProvider.notifier)
                              .cerca()
                        : _vaiAvanti,
                    child: Text(
                      trovati == null && !negato
                          ? 'GUARDA CHI C’È'
                          : 'CONTINUA',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({
    required this.stato,
    required this.negato,
    required this.onCerca,
  });

  final AsyncValue<List<dynamic>?> stato;
  final bool negato;
  final VoidCallback onCerca;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (stato.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: palette.accent),
      );
    }

    if (negato) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Text(
          'Va bene lo stesso. Se cambi idea, il permesso si accende dalle '
          'impostazioni del telefono alla voce CRASY, e li ritrovi nella '
          'pagina degli amici.',
          style: context.texts.bodyMedium?.copyWith(
            color: palette.textFaint,
          ),
        ),
      );
    }

    final trovati = stato.valueOrNull;

    if (trovati == null || trovati.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      children: [
        for (final chi in trovati) SuggestedFriendRow(suggested: chi),
      ],
    );
  }
}
