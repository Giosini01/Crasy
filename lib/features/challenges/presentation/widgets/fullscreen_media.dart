import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/share/share_entry.dart';
import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/video_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Una partecipazione a schermo intero.
///
/// **La foto e' il contenuto, e dentro la griglia della gara ne vede un
/// quadrato di due dita.** Qui prende tutto lo schermo su fondo nero, che e'
/// l'unico posto di CRASY in cui il nero fa da fondo: e' la sala buia in cui si
/// guarda una cosa sola.
///
/// Si scorre da una partecipazione all'altra con il dito, senza tornare
/// indietro: guardare le foto di una gara e' un gesto continuo, e chiudere e
/// riaprire venti volte lo spezzerebbe. Il doppio tocco accende la fiamma come
/// ovunque nell'app — chi sta guardando una foto a schermo intero e' esattamente
/// chi ha piu' voglia di votarla.
class FullscreenMedia extends ConsumerStatefulWidget {
  const FullscreenMedia({
    required this.entries,
    required this.initialIndex,
    super.key,
  });

  final List<ChallengeEntry> entries;
  final int initialIndex;

  /// Apre la vista. E' un `Navigator.push` e non una rotta del router: e' una
  /// finestra sopra la schermata, non un posto in cui si atterra da un
  /// indirizzo — e da qui il tasto indietro del telefono la chiude, che e'
  /// quello che tutti si aspettano.
  static Future<void> open(
    BuildContext context, {
    required List<ChallengeEntry> entries,
    required ChallengeEntry entry,
  }) {
    final index = entries.indexWhere((item) => item.id == entry.id);

    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: AppColors.ink,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: FullscreenMedia(
            entries: entries,
            initialIndex: index < 0 ? 0 : index,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<FullscreenMedia> createState() => _FullscreenMediaState();
}

class _FullscreenMediaState extends ConsumerState<FullscreenMedia> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final current = entries[_index.clamp(0, entries.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: entries.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => _Slide(entry: entries[index]),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  position: '${_index + 1} / ${entries.length}',
                  onClose: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _BottomBar(entry: current),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una singola partecipazione dentro la vista.
///
/// La foto si puo' ingrandire con due dita. Non e' un vezzo: le challenge si
/// vincono con i dettagli — cosa c'e' scritto sul cartello, che faccia ha fatto
/// lo sconosciuto — e su un telefono quei dettagli si vedono solo avvicinandosi.
class _Slide extends ConsumerWidget {
  const _Slide({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = entry.mediaUrl;

    if (url.isEmpty) {
      return const SizedBox.shrink();
    }

    final media = entry.isVideo
        ? VideoFrame(url: url)
        : InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          );

    return GestureDetector(
      // Il doppio tocco vale anche qui, e a fiamma gia' accesa non la spegne:
      // nessuno ripete lo stesso gesto per disfare quello che ha appena fatto.
      onDoubleTap: () {
        if (!ref.read(entryVotedProvider(entry.id))) {
          giveFire(context, ref, entry, voted: true);
        }
      },
      child: Center(child: media),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.position, required this.onClose});

  final String position;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppColors.paper),
            tooltip: 'Chiudi',
          ),
          const Spacer(),
          Text(
            position,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.paper),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Chi l'ha mandata e quante fiamme ha preso.
///
/// Sono le uniche due cose che servono qui: il resto della gara sta nella
/// schermata sotto, e riproporlo su fondo nero vorrebbe dire coprire la foto
/// con quello che si e' appena chiuso per vederla.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.entry});

  final ChallengeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voted = ref.watch(entryVotedProvider(entry.id));
    final counted = entry.votes + ref.watch(entryVoteDeltaProvider(entry.id));
    final votes = counted < 0 ? 0 : counted;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      color: AppColors.ink.withValues(alpha: 0.55),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.userProfileOf(entry.userId));
              },
              child: Text(
                '@${entry.authorName}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.paper),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Condividere sta accanto alla fiamma, non nascosto in un menu: e'
          // il gesto con cui chi e' in gara si porta dentro i voti, ed e' anche
          // il modo in cui CRASY incontra gente che non la conosce.
          IconButton(
            onPressed: () => ShareEntry.send(
              context,
              challengeId: entry.challengeId,
              entryId: entry.id,
              challengeTitle: entry.challengeTitle,
            ),
            tooltip: 'Condividi',
            icon: const Icon(Icons.ios_share_rounded, color: AppColors.paper),
          ),
          InkWell(
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
                    size: 22,
                    color: voted ? AppColors.crasyRed : AppColors.paper,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$votes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: voted ? AppColors.crasyRed : AppColors.paper,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
