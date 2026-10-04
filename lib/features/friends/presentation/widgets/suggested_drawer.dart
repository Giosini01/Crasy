import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// **La porta per "Trova i tuoi amici".**
///
/// Era un cassetto: si toccava e scendeva un pannello con dentro le persone.
/// Funzionava, e stava nel posto sbagliato — un elenco di gente appoggiato in
/// mezzo al proprio profilo, o in fondo a una schermata che parla d'altro. Chi
/// c'e' gia' e chi va invitato sono una schermata loro, con le due meta'
/// separate e lo spazio per scorrerle.
///
/// Qui resta la riga che ci porta. Il nome della classe e' rimasto quello di
/// prima perche' compare in tre schermate, e cambiarlo avrebbe toccato tre
/// file senza dire niente di nuovo.
class SuggestedDrawer extends StatelessWidget {
  const SuggestedDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Dal browser non si mostra: una pagina web non ha una rubrica da leggere,
    // e una riga che porta dove non puo' funzionare e' peggio di nessuna riga.
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.findFriends),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contact_phone_rounded, size: 14, color: palette.accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'TROVA I TUOI AMICI',
              style: context.texts.labelSmall?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            // La freccia va a destra, non in giu': in giu' prometteva una cosa
            // che si apriva li' sotto, e adesso si apre un'altra schermata.
            Icon(Icons.chevron_right_rounded, size: 18, color: palette.accent),
          ],
        ),
      ),
    );
  }
}
