import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/features/matches/domain/entities/match_person.dart';
import 'package:flutter/material.dart';

/// La foto di un match: l'Istantanea di oggi finche' c'e', poi la foto
/// profilo.
///
/// **Il match non muore con la foto.** Passate ventiquattr'ore l'Istantanea
/// viene cancellata sul serio, e questa scheda lo dice invece di lasciare un
/// buco che sembrerebbe un guasto. Il giorno dopo, appena quella persona si fa
/// vedere di nuovo, qui ricompare la faccia di oggi.
class MatchPhoto extends StatelessWidget {
  const MatchPhoto({
    required this.person,
    this.radius = AppRadius.md,
    this.showExpiredNotice = true,
    super.key,
  });

  final MatchPerson person;
  final double radius;

  /// L'etichetta "Istantanea scaduta" sopra il ripiego.
  final bool showExpiredNotice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final expired = person.expiredAt(now);
    final url = person.photoAt(now);

    final name = person.name.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    final blank = ColoredBox(
      color: palette.surfaceMuted,
      child: Center(
        child: Text(
          initial,
          style: context.texts.displaySmall?.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isEmpty)
            blank
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (context, _, _) => blank,
            ),
          if (expired && showExpiredNotice)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs,
                  vertical: 3,
                ),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  'Istantanea scaduta',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
