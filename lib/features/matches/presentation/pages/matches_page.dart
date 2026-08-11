import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_shadows.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:app_incontri/features/matches/domain/entities/match_person.dart';
import 'package:app_incontri/features/matches/presentation/pages/match_chat_page.dart';
import 'package:app_incontri/features/matches/presentation/providers/matches_providers.dart';
import 'package:app_incontri/features/matches/presentation/widgets/match_photo.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// I match: le persone a cui e' piaciuta la tua Istantanea mentre la loro
/// piaceva a te.
class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    final myInterests =
        ref.watch(currentUserProfileProvider).valueOrNull?.interests ??
        const <String>[];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EyebrowLabel('Match'),
                    const SizedBox(height: 2),
                    Text(
                      'Le vostre istantanee si sono incontrate. ❤️',
                      style: context.texts.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: matches.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const _MatchesEmpty(
                    title: 'Non riusciamo a caricare i match.',
                    description: 'Riprova fra poco.',
                    beating: false,
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const _MatchesEmpty(
                        title: 'Ancora nessun match.',
                        description:
                            'Il match nasce quando il cuore e reciproco.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _MatchCard(
                        person: list[index],
                        // Gli interessi in comune si contano qui: i propri
                        // sono gia' in memoria, quelli dell'altro arrivano nel
                        // documento del match.
                        shared: list[index].sharedLabelWith(myInterests),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una scheda di match: la foto di oggi, chi e', e da dove si riparte.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.person, required this.shared});

  final MatchPerson person;

  /// "2 interessi in comune", vuoto se non ce ne sono.
  final String shared;

  void _open(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => MatchChatPage(person: person),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final started = person.hasMessage || person.hasMyMessage;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _open(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verticale e alta, come nel Feed: e' la foto di oggi, e qui
                // vale quanto vale li'.
                SizedBox(
                  width: 96,
                  height: 128,
                  child: MatchPhoto(person: person),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${person.name}, ${person.age}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: palette.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                shared.isEmpty
                                    ? person.distanceLabel
                                    : '${person.distanceLabel} · $shared',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall?.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (person.vibeChip.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          _SoftTag(text: person.vibeChip),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        if (started)
                          _StartedPreview(person: person)
                        else
                          // Un match senza una parola muore li'. Dirlo e
                          // offrire il gesto nello stesso punto e' l'unica
                          // cosa che possiamo fare perche' non succeda.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nessun messaggio ancora.',
                                style: context.texts.bodySmall?.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              TextButton(
                                onPressed: () => _open(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Scrivi qualcosa'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le due righe scritte col cuore, in anteprima sulla scheda.
class _StartedPreview extends StatelessWidget {
  const _StartedPreview({required this.person});

  final MatchPerson person;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (person.hasMessage)
          Text(
            '"${person.message}"',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textPrimary,
            ),
          ),
        if (person.hasMyMessage) ...[
          const SizedBox(height: 2),
          Text(
            'Tu: "${person.myMessage}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SoftTag extends StatelessWidget {
  const _SoftTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.texts.bodySmall?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MatchesEmpty extends StatelessWidget {
  const _MatchesEmpty({
    required this.title,
    required this.description,
    this.beating = true,
  });

  final String title;
  final String description;

  /// Il cuore batte quando si sta aspettando; su un errore resta fermo, che
  /// un guasto non e' una cosa da festeggiare.
  final bool beating;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (beating)
              const _BeatingHeart()
            else
              const GlyphTile(icon: Icons.heart_broken_rounded),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un cuore che batte piano.
///
/// E' l'unica animazione di questa schermata, e sta qui perche' e' l'unico
/// punto in cui non c'e' niente da guardare: senza, la pagina vuota
/// sembrerebbe rotta. Il battito e' lento — nessun rimbalzo — perche' deve
/// accompagnare l'attesa, non chiedere attenzione.
class _BeatingHeart extends StatefulWidget {
  const _BeatingHeart();

  @override
  State<_BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<_BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.94,
    end: 1.06,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: palette.brandTint,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.favorite_rounded,
          size: 38,
          color: palette.brand,
        ),
      ),
    );
  }
}
