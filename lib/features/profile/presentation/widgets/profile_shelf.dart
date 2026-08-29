import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/profile/presentation/widgets/trophy_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Cosa si sta guardando di un profilo.
///
/// **Non "tutte le foto".** Una raccolta di tutto quello che uno ha mandato da
/// quando esiste racconta la quantita', non la persona: dopo trenta gare sono
/// trenta quadrati in cui le due che contano stanno in fondo.
///
/// Tre sezioni, e sono le tre domande che uno si fa davvero guardando un
/// profilo: **dove sta gareggiando adesso**, **cosa ha vinto**, **cosa ha
/// fatto fare agli altri**.
///
/// L'ultima e' la piu' recente e la meno ovvia. Chi lancia una challenge mette
/// dei soldi e non gareggia, quindi non vincera' mai niente: senza una sezione
/// sua, del gesto piu' impegnativo che si possa fare qui dentro non resterebbe
/// traccia da nessuna parte. E' anche l'unico posto in cui il profilo racconta
/// una cosa che uno ha **ordinato** invece che eseguito.
enum ProfileShelf {
  live('IN GARA'),
  trophies('TROFEI'),
  commissioned('LANCIATE');

  const ProfileShelf(this.label);

  final String label;
}

/// Le due parole in cima alla griglia, come i filtri della ricerca.
class ProfileShelfTabs extends StatelessWidget {
  const ProfileShelfTabs({
    required this.selected,
    required this.onPick,
    super.key,
  });

  final ProfileShelf selected;
  final void Function(ProfileShelf shelf) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (final shelf in ProfileShelf.values)
            GestureDetector(
              onTap: () => onPick(shelf),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Text(
                  shelf.label,
                  style: context.texts.labelSmall?.copyWith(
                    color: shelf == selected
                        ? palette.accent
                        : palette.textFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le partecipazioni in gara adesso.
///
/// **In gara** vuol dire "la challenge e' ancora aperta", non "l'ho mandata di
/// recente": una foto di tre giorni fa in una gara che dura una settimana e'
/// ancora in gioco, e una di stamattina in una gara chiusa non lo e' piu'.
///
/// Le altre due sezioni non passano da qui: **non sono fatte di
/// partecipazioni**. Una partecipazione viene cancellata quarantotto ore dopo
/// la fine della gara — foto compresa — quindi una bacheca costruita su quelle
/// si svuoterebbe da sola due giorni dopo ogni vittoria. I trofei stanno sulla
/// gara, che resta.
List<ChallengeEntry> liveEntries(
  List<ChallengeEntry> entries,
  Set<String> liveChallengeIds,
) {
  return [
    for (final entry in entries)
      if (liveChallengeIds.contains(entry.challengeId)) entry,
  ];
}

/// Le gare lanciate da una persona: prima quelle aperte adesso, poi i trofei.
///
/// **Le due meta' non possono stare nella stessa griglia**, e non e' una scelta
/// grafica: la figurina e' costruita attorno alla foto di chi ha vinto, e una
/// gara ancora aperta un vincitore non ce l'ha. Infilarcela dentro darebbe un
/// rettangolo vuoto con un premio sopra, cioe' l'aria di una cosa rotta proprio
/// dove si sta guardando se qualcuno ha davvero messo dei soldi.
///
/// Le aperte prendono una riga per uno con il tempo che manca: sono poche —
/// quante gare puo' avere aperte una persona nello stesso momento — e sono
/// l'unica cosa di questa bacheca su cui si possa ancora fare qualcosa.
class CommissionedShelf extends StatelessWidget {
  const CommissionedShelf({required this.challenges, super.key});

  /// Gia' nell'ordine giusto: ci ha pensato `commissionedOrder`.
  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    // **La divisione si fa su `hasTrophy`, non sull'orologio.** Quello che
    // arriva qui contiene gia' solo gare aperte e gare con un trofeo — ci ha
    // pensato `commissionedOrder` — quindi "ha un trofeo" e "e' finita" sono la
    // stessa cosa, e la prima delle due non dipende da che ora e'.
    //
    // Fra il momento in cui il repository ha fatto l'ordine e questo disegno
    // passa un istante, ma in quell'istante una gara puo' essere scaduta:
    // rileggendo l'orologio finirebbe fra i trofei **senza avere una foto**,
    // cioe' una figurina vuota. Cosi' invece resta fra le aperte, con il conto
    // alla rovescia a zero, finche' il vincitore non c'e' davvero.
    final live = [
      for (final challenge in challenges)
        if (!challenge.hasTrophy) challenge,
    ];

    final trophies = [
      for (final challenge in challenges)
        if (challenge.hasTrophy) challenge,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // **Obbligatorio, non un'ottimizzazione.** Questa colonna finisce dentro
      // una `ListView`, che offre ai figli un'altezza senza limite: con la
      // misura predefinita — prendersi tutto lo spazio — non c'e' un "tutto" da
      // prendersi, e si va in errore di impaginazione.
      mainAxisSize: MainAxisSize.min,
      children: [
        if (live.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: EyebrowLabel('APERTE ADESSO'),
          ),
          for (final challenge in live)
            _LiveCommissionRow(challenge: challenge),
        ],
        if (trophies.isNotEmpty) ...[
          // L'occhiello sulle concluse compare **solo se ci sono anche delle
          // aperte**: da solo sopra una griglia di trofei non separerebbe
          // niente da niente, e sarebbe una parola in piu' su una schermata che
          // ne ha gia' tre.
          if (live.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: EyebrowLabel('CONCLUSE'),
            ),
          TrophyGrid(challenges: trophies, kind: TrophyKind.commissioned),
        ],
      ],
    );
  }
}

/// Una gara aperta, nella bacheca di chi l'ha lanciata.
///
/// Premio, titolo e quanto manca. Niente foto: la faccia di una gara la mettono
/// i partecipanti, e finche' e' aperta cambia di continuo — una copertina qui
/// dentro sarebbe vecchia un minuto dopo essere stata disegnata.
class _LiveCommissionRow extends StatelessWidget {
  const _LiveCommissionRow({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    challenge.prizeLabel,
                    style: texts.displaySmall?.copyWith(color: palette.accent),
                  ),
                ),
                // Il conto alla rovescia si fa rosso nell'ultima ora: e' il
                // momento in cui chi ha messo i soldi ha ancora tempo di dire
                // in giro che la gara sta per chiudere.
                CountdownText(
                  target: challenge.endsAt,
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                  urgentColor: palette.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              challenge.title.toUpperCase(),
              style: texts.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: palette.line, height: 1),
          ],
        ),
      ),
    );
  }
}
