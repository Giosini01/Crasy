import 'dart:math' as math;

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

/// **La barra sottile che si riempie.** Quando il numero cambia scorre fino
/// al punto nuovo invece di saltarci: e' cosi' che si vede che qualcosa e'
/// appena successo.
class BarraDelGioco extends StatelessWidget {
  const BarraDelGioco({
    required this.frazione,
    this.altezza = 4,
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
            backgroundColor: palette.surfaceMuted,
            color: spenta ? palette.textFaint : palette.accent,
          ),
        ),
      ),
    );
  }
}

/// **Il livello accanto al nome, che vedono tutti.** Fondo bianco, scritta
/// rossa, e il numero dentro un cerchio rosso: si nota senza gridare, e
/// accanto alla serie — contornata di rosso — non si confonde.
class LivelloBadge extends ConsumerWidget {
  const LivelloBadge({required this.livello, this.onTap, super.key});

  final int livello;

  /// Sul proprio profilo si tocca e si aprono le sfide.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final regole = ref.watch(regoleDelGiocoProvider).valueOrNull;
    final numero = livello < 1 ? 1 : livello;
    final nome = regole?.nomeDelLivello(numero);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
        decoration: BoxDecoration(
          color: palette.background,
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.25),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 19,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$numero',
                style: context.texts.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: palette.onAccent,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              nome == null
                  ? 'LIVELLO $numero'
                  : 'LIV. $numero · ${nome.toUpperCase()}',
              style: context.texts.labelSmall?.copyWith(
                fontSize: 11,
                color: palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Il livello che gira attorno alla foto del profilo.** Un anello sottile
/// che si riempie con gli XP verso il livello dopo, e in basso il numero del
/// livello in un cerchio rosso.
class AnelloDelLivello extends ConsumerWidget {
  const AnelloDelLivello({
    required this.child,
    required this.livello,
    required this.xp,
    required this.diametro,
    super.key,
  });

  final Widget child;
  final int livello;
  final int xp;
  final double diametro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final regole = ref.watch(regoleDelGiocoProvider).valueOrNull;
    final progresso = regole == null ? 0.0 : regole.livelloPer(xp).progresso;
    final numero = livello < 1 ? 1 : livello;

    return SizedBox(
      width: diametro,
      height: diametro + 8,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: progresso),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, valore, _) => CustomPaint(
              size: Size.square(diametro),
              painter: _Anello(
                valore: valore,
                binario: palette.surfaceMuted,
                colore: palette.accent,
              ),
            ),
          ),
          Positioned(top: 8, child: child),
          Positioned(
            top: diametro - 18,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: palette.background, width: 3),
              ),
              child: Text(
                '$numero',
                style: context.texts.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: palette.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Anello extends CustomPainter {
  _Anello({required this.valore, required this.binario, required this.colore});

  final double valore;
  final Color binario;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    const spessore = 4.0;
    final area = (Offset.zero & size).deflate(spessore / 2);
    final tratto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spessore
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(area, 0, math.pi * 2, false, tratto..color = binario);

    if (valore > 0) {
      canvas.drawArc(
        area,
        -math.pi / 2,
        math.pi * 2 * valore,
        false,
        tratto..color = colore,
      );
    }
  }

  @override
  bool shouldRepaint(_Anello vecchio) =>
      vecchio.valore != valore ||
      vecchio.colore != colore ||
      vecchio.binario != binario;
}

/// **Le sfide di oggi, sul profilo: una riga sola.** Quante ne hai fatte,
/// quanto manca al livello dopo, e si apre sulle sfide.
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
    final fatte = oggi.where((s) => s.stato == StatoSfida.completata).length;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.sfide),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: palette.line),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accentTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt_rounded, size: 20, color: palette.accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SFIDE DI OGGI',
                    style: texts.labelSmall?.copyWith(color: palette.accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    livello == null || stato == null
                        ? 'Stanno arrivando'
                        : [
                            '$fatte su ${oggi.length} fatte',
                            if (livello.ultimo)
                              'livello massimo'
                            else
                              '${livello.xpA! - stato.xp} XP al livello '
                                  '${livello.numero + 1}',
                          ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            for (final voce in oggi)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: voce.stato == StatoSfida.completata
                      ? palette.accent
                      : palette.line,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// **Il livello in cima alla schermata delle sfide**: il nome in grande, la
/// barra sottile, quanto manca.
class LivelloInGrande extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final prossimo = livello.ultimo
        ? null
        : ref
              .watch(regoleDelGiocoProvider)
              .valueOrNull
              ?.nomeDelLivello(livello.numero + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LIVELLO ${livello.numero}',
          style: texts.labelSmall?.copyWith(color: palette.accent),
        ),
        const SizedBox(height: 2),
        Text(livello.nome.toUpperCase(), style: texts.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        BarraDelGioco(frazione: livello.progresso),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              '$xp XP',
              style: texts.labelMedium?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                livello.ultimo
                    ? 'Livello massimo'
                    : '${livello.xpA! - xp} al prossimo'
                          '${prossimo == null ? '' : ' · $prossimo'}',
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
        const SizedBox(height: 2),
        Text(
          sfideCompletate == 1
              ? '1 sfida completata'
              : '$sfideCompletate sfide completate',
          style: texts.bodySmall?.copyWith(color: palette.textFaint),
        ),
      ],
    );
  }
}

/// Il tondo dell'icona: rosso tenue, rosso pieno con la spunta se e' fatta,
/// il lucchetto se aspetta.
class _Tondo extends StatelessWidget {
  const _Tondo({required this.voce});

  final SfidaInVista voce;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fatta = voce.stato == StatoSfida.completata;

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fatta ? palette.accent : palette.accentTint,
        shape: BoxShape.circle,
      ),
      child: Icon(
        fatta
            ? Icons.check_rounded
            : voce.stato == StatoSfida.bloccata
            ? Icons.lock_rounded
            : iconaDelGioco(voce.sfida.icona),
        size: 19,
        color: fatta ? palette.onAccent : palette.accent,
      ),
    );
  }
}

/// **Una sfida di oggi: una riga compatta.** Il tondo, il titolo con il
/// conto, la barra sottile, i punti a destra.
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
      opacity: bloccata ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.line)),
        ),
        child: Row(
          children: [
            _Tondo(voce: voce),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sfida.titolo,
                          style: texts.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        fatta
                            ? 'FATTA'
                            : '${voce.progresso}/${sfida.obiettivo}',
                        style: texts.labelSmall?.copyWith(
                          color: fatta ? palette.accent : palette.textFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sfida.descrizione,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  BarraDelGioco(frazione: voce.frazione, spenta: bloccata),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '+${sfida.xp} XP',
              style: texts.labelLarge?.copyWith(
                color: fatta ? palette.textFaint : palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Un traguardo: un mattone della griglia.** Fatto si colora, bloccato si
/// sbiadisce e dice che viene dopo il precedente.
class TraguardoMattone extends StatelessWidget {
  const TraguardoMattone({required this.voce, super.key});

  final SfidaInVista voce;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final sfida = voce.sfida;
    final fatta = voce.stato == StatoSfida.completata;
    final bloccata = voce.stato == StatoSfida.bloccata;

    return Opacity(
      opacity: bloccata ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: fatta ? palette.accentTint : null,
          border: Border.all(color: fatta ? palette.accentTint : palette.line),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Tondo(voce: voce),
                const Spacer(),
                Text(
                  '+${sfida.xp} XP',
                  style: texts.labelSmall?.copyWith(
                    color: fatta ? palette.textFaint : palette.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              sfida.titolo,
              style: texts.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              bloccata
                  ? 'Dopo la precedente'
                  : fatta
                  ? 'Fatto'
                  : '${voce.progresso}/${sfida.obiettivo} · ${sfida.descrizione}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            BarraDelGioco(frazione: voce.frazione, spenta: bloccata),
          ],
        ),
      ),
    );
  }
}
