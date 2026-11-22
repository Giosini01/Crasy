import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/gioco/domain/entities/regole_del_gioco.dart';
import 'package:crasy/features/gioco/domain/sfide_in_vista.dart';
import 'package:crasy/features/gioco/presentation/providers/gioco_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// L'icona di una sfida, dal nome scritto nelle regole. Un nome che non si
/// conosce diventa la stella: una sfida nuova dal pannello non deve rompere
/// niente.
IconData iconaDelGioco(String nome) => switch (nome) {
  'foto' => Icons.photo_camera_rounded,
  'fiamma' => Icons.local_fire_department_rounded,
  'amici' => Icons.group_rounded,
  'commento' => Icons.mode_comment_rounded,
  'coppa' => Icons.emoji_events_rounded,
  'serie' => Icons.bolt_rounded,
  'calendario' => Icons.calendar_month_rounded,
  _ => Icons.star_rounded,
};

/// **La barra che si riempie.** Quando il numero cambia scorre fino al punto
/// nuovo invece di saltarci: e' cosi' che si vede che qualcosa e' appena
/// successo.
class BarraDelGioco extends StatelessWidget {
  const BarraDelGioco({
    required this.frazione,
    this.altezza = 8,
    this.spenta = false,
    super.key,
  });

  final double frazione;
  final double altezza;

  /// Grigia: per i traguardi che aspettano il loro turno.
  final bool spenta;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: altezza,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: frazione.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, valore, _) => LinearProgressIndicator(
            value: valore,
            minHeight: altezza,
            backgroundColor: palette.line,
            color: spenta ? palette.textFaint : palette.accent,
          ),
        ),
      ),
    );
  }
}

/// **Il livello accanto al nome, che vedono tutti.**
///
/// Pieno e scuro, non rosso: accanto c'e' la serie, contornata di rosso, e
/// due distintivi uguali si leggerebbero come uno. Il nome del livello viene
/// dalle regole; finche' non arrivano basta il numero.
class LivelloBadge extends ConsumerWidget {
  const LivelloBadge({required this.livello, super.key});

  final int livello;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final regole = ref.watch(regoleDelGiocoProvider).valueOrNull;
    final numero = livello < 1 ? 1 : livello;
    final nome = regole?.nomeDelLivello(numero);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: palette.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.military_tech_rounded,
            size: 13,
            color: palette.background,
          ),
          const SizedBox(width: 3),
          Text(
            nome == null
                ? 'LIVELLO $numero'
                : 'LIV. $numero · ${nome.toUpperCase()}',
            style: context.texts.labelSmall?.copyWith(
              fontSize: 11,
              color: palette.background,
            ),
          ),
        ],
      ),
    );
  }
}

/// **Il livello, sul profilo.** Dice a che punto sei e si apre sulle sfide.
///
/// Sta sotto il portafoglio, con la stessa forma e senza il suo colore: il
/// portafoglio vale dei soldi, questo racconta quanto giochi.
class LivelloCard extends ConsumerWidget {
  const LivelloCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;

    // Le sfide di oggi si chiedono al server appena il profilo si apre: il
    // giorno nuovo, se e' arrivato, arriva anche qui.
    ref.watch(apriLeSfideProvider);

    final livello = ref.watch(livelloAttualeProvider);
    final stato = ref.watch(statoDelGiocoProvider).valueOrNull;
    final oggi = ref.watch(sfideDiOggiProvider);
    final fatteOggi = oggi
        .where((s) => s.stato == StatoSfida.completata)
        .length;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.sfide),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: palette.line),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'LIVELLO E SFIDE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texts.labelSmall?.copyWith(color: palette.accent),
                  ),
                ),
                if (oggi.isNotEmpty)
                  Text(
                    'OGGI $fatteOggi/${oggi.length}',
                    style: texts.labelSmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (livello == null || stato == null)
              Text(
                'Le sfide di oggi stanno arrivando.',
                style: texts.bodySmall?.copyWith(color: palette.textSecondary),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${livello.numero}',
                    style: texts.displaySmall?.copyWith(color: palette.accent),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        livello.nome.toUpperCase(),
                        style: texts.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${stato.xp} XP', style: texts.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              BarraDelGioco(frazione: livello.progresso),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (livello.ultimo)
                    'Livello massimo'
                  else
                    '${livello.xpA! - stato.xp} XP al livello ${livello.numero + 1}',
                  stato.sfideCompletate == 1
                      ? '1 sfida completata'
                      : '${stato.sfideCompletate} sfide completate',
                ].join(' · '),
                style: texts.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// **Una sfida, del giorno o di sempre.** Icona, titolo, cosa chiede, quanto
/// vale, a che punto sei. Fatta si colora; bloccata si spegne e dice perche'.
class SfidaCard extends StatelessWidget {
  const SfidaCard({required this.voce, super.key});

  final SfidaInVista voce;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final sfida = voce.sfida;
    final fatta = voce.stato == StatoSfida.completata;
    final bloccata = voce.stato == StatoSfida.bloccata;

    return Opacity(
      opacity: bloccata ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: fatta ? palette.accentTint : null,
          border: Border.all(color: fatta ? palette.accentTint : palette.line),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fatta ? palette.accent : palette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                fatta
                    ? Icons.check_rounded
                    : bloccata
                    ? Icons.lock_rounded
                    : iconaDelGioco(sfida.icona),
                size: 20,
                color: fatta ? palette.onAccent : palette.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sfida.titolo,
                          style: texts.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '+${sfida.xp} XP',
                        style: texts.labelLarge?.copyWith(
                          color: fatta || bloccata
                              ? palette.textSecondary
                              : palette.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sfida.descrizione,
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  BarraDelGioco(
                    frazione: voce.frazione,
                    altezza: 6,
                    spenta: bloccata,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${voce.progresso}/${sfida.obiettivo}',
                        style: texts.labelMedium,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          switch (voce.stato) {
                            StatoSfida.daFare => 'DA FARE',
                            StatoSfida.inCorso => 'IN CORSO',
                            StatoSfida.completata => 'FATTA',
                            StatoSfida.bloccata => 'BLOCCATA',
                          },
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texts.labelSmall?.copyWith(
                            color: fatta ? palette.accent : palette.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Il livello in grande**, in cima alla schermata delle sfide.
class LivelloInGrande extends StatelessWidget {
  const LivelloInGrande({
    required this.livello,
    required this.xp,
    required this.sfideCompletate,
    super.key,
  });

  final LivelloAttuale livello;
  final int xp;
  final int sfideCompletate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVELLO ${livello.numero}',
            style: texts.labelSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            livello.nome.toUpperCase(),
            style: texts.displaySmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          BarraDelGioco(frazione: livello.progresso, altezza: 10),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('$xp XP', style: texts.labelLarge),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  livello.ultimo
                      ? 'Livello massimo'
                      : '${livello.xpA! - xp} al prossimo',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.labelMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            sfideCompletate == 1
                ? '1 sfida completata'
                : '$sfideCompletate sfide completate',
            style: texts.bodySmall?.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
