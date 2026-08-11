import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/features/feed/domain/entities/feed_person.dart';
import 'package:app_incontri/features/profile/presentation/widgets/interests_picker.dart';
import 'package:flutter/material.dart';

/// Il profilo di una persona incontrata nel Per Te.
///
/// Mostra soltanto cio' che il server ha gia' messo nella voce di feed: il
/// client non puo' leggere i profili altrui, e questa pagina non fa eccezione.
/// Da qui si decide, senza dover tornare indietro.
class PersonProfilePage extends StatelessWidget {
  const PersonProfilePage({
    required this.person,
    required this.onDecide,
    super.key,
  });

  final FeedPerson person;

  /// Riceve `true` per il cuore, `false` per lo scarto. La pagina si chiude
  /// da sola: la scelta si prende una volta e vale.
  final void Function({required bool liked}) onDecide;

  void _decide(BuildContext context, {required bool liked}) {
    Navigator.of(context).pop();
    onDecide(liked: liked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Torna indietro',
                  ),
                  Expanded(
                    child: Text(
                      person.name,
                      style: context.texts.titleLarge,
                    ),
                  ),
                ],
              ),
              Divider(color: palette.border, height: 0.5, thickness: 0.5),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _Header(person: person),
                    if (person.hasIcebreaker) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('Oggi...', style: context.texts.labelSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(person.icebreaker, style: context.texts.bodyLarge),
                    ],
                    if (person.interests.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        person.sharedInterests.isEmpty
                            ? 'Interessi'
                            : person.sharedInterestsLabel,
                        style: context.texts.labelSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      InterestChips(
                        ids: person.interests,
                        highlighted: person.sharedInterests,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      person.dailies.length == 1
                          ? 'Istantanea di oggi'
                          : 'Istantanee di oggi',
                      style: context.texts.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Sta in fondo ma e' la cosa piu' grande della pagina:
                    // l'ordine di lettura porta qui, e qui c'e' la persona
                    // com'e' oggi.
                    _DailyStrip(person: person),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _decide(context, liked: false),
                        child: const Text('Passa'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _decide(context, liked: true),
                        child: const Text('Mi piace'),
                      ),
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

class _Header extends StatelessWidget {
  const _Header({required this.person});

  final FeedPerson person;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        // Piccola di proposito: la foto profilo serve a riconoscere chi e',
        // non a rappresentarlo. Quella che conta e' l'Istantanea, in fondo.
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: person.hasPhoto
              ? Image.network(
                  person.photoUrl,
                  fit: BoxFit.cover,
                  width: 52,
                  height: 52,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (context, _, _) => _Initial(person: person),
                )
              : _Initial(person: person),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${person.name}, ${person.age}',
                style: context.texts.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(person.distanceLabel, style: context.texts.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.person});

  final FeedPerson person;

  @override
  Widget build(BuildContext context) {
    final name = person.name.trim();

    return Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: context.texts.displaySmall?.copyWith(
        color: context.palette.brand,
      ),
    );
  }
}

/// Le Istantanee di oggi in fila, per rivederle senza tornare alla scheda.
class _DailyStrip extends StatelessWidget {
  const _DailyStrip({required this.person});

  final FeedPerson person;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Alta e larga: e' il contenuto principale della pagina, non una striscia
    // di anteprime da scorrere di sfuggita.
    final single = person.dailies.length == 1;

    return SizedBox(
      height: single ? 380 : 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: single ? const NeverScrollableScrollPhysics() : null,
        itemCount: person.dailies.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final daily = person.dailies[index];

          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: ColoredBox(
              color: palette.surfaceMuted,
              child: SizedBox(
                width: single ? 285 : 225,
                child: Image.network(
                  daily.photoUrl,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (context, _, _) => Icon(
                    Icons.broken_image_outlined,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
