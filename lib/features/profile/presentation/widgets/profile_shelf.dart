import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
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
/// **FIGURINE, non TROFEI.** Un trofeo puo' essere qualunque cosa — una
/// vittoria, una gara pagata, un riconoscimento — e infatti accanto c'era
/// LANCIATE, che di trofei e' piena anche lei. Due parole che si somigliano
/// non dividono niente.
///
/// Figurina invece dice **cos'e' quell'oggetto**: la foto con cui si e' vinto,
/// dentro la sua cornice, che si gira in mano e si colleziona. E si oppone a
/// LANCIATE senza bisogno di spiegazioni — una l'hai vinta, l'altra l'hai
/// fatta fare.
enum ProfileShelf {
  live('IN GARA'),
  trophies('FIGURINE'),
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

/// Cosa si guarda dentro le LANCIATE.
///
/// **Tre cose diverse che prima stavano in fila.** Una gara aperta e' una cosa
/// su cui si puo' ancora fare qualcosa — entrarci, guardare a che punto e' — e
/// una finita e' un ricordo; metterle una sotto l'altra vuol dire che chi cerca
/// la prima scorre in mezzo alle seconde. E quelle riservate agli amici sono
/// un'altra faccenda ancora: non le vede tutto il mondo, e chi non e' dei loro
/// non deve nemmeno sapere che esistono.
enum CommissionedFilter {
  /// Aperte adesso: ci si puo' ancora entrare.
  active('ATTIVE'),

  /// Finite: resta la targa.
  closed('CHIUSE'),

  /// Lanciate al proprio gruppo. **Questa scheda compare solo a chi le puo'
  /// vedere**, e non serve un controllo per ottenerlo: la lettura del database
  /// non le porta nemmeno a chi non e' dei loro, quindi l'elenco arriva vuoto e
  /// la scheda non si disegna.
  friends('AMICI');

  const CommissionedFilter(this.label);

  final String label;
}

/// Le gare lanciate da una persona, divise in tre.
///
/// L'ordine dentro ogni scheda lo ha gia' deciso `commissionedOrder`: qui si
/// smista soltanto.
class CommissionedShelf extends StatefulWidget {
  const CommissionedShelf({required this.challenges, super.key});

  /// Gia' nell'ordine giusto: ci ha pensato `commissionedOrder`.
  final List<Challenge> challenges;

  @override
  State<CommissionedShelf> createState() => _CommissionedShelfState();
}

class _CommissionedShelfState extends State<CommissionedShelf> {
  CommissionedFilter? _scelta;

  /// Se questa gara e' chiusa.
  ///
  /// **Due modi di esserlo, e non coincidono.** L'orologio e' passato, oppure
  /// qualcuno l'ha chiusa prima: una sfida mirata si chiude nell'istante del
  /// verdetto, che puo' arrivare ore prima della scadenza.
  static bool _chiusa(Challenge challenge, DateTime now) =>
      challenge.winnerEntryId != null || challenge.hasEndedAt(now);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Le riservate stanno tutte insieme, aperte e chiuse: sono poche, e quello
    // che le distingue dalle altre — chi puo' vederle — conta piu' di quanto le
    // distingua fra loro.
    final amici = [
      for (final challenge in widget.challenges)
        if (challenge.isForFriends) challenge,
    ];

    final pubbliche = [
      for (final challenge in widget.challenges)
        if (!challenge.isForFriends) challenge,
    ];

    final aperte = [
      for (final challenge in pubbliche)
        if (!_chiusa(challenge, now)) challenge,
    ];

    final chiuse = [
      for (final challenge in pubbliche)
        if (_chiusa(challenge, now)) challenge,
    ];

    final dentro = {
      CommissionedFilter.active: aperte,
      CommissionedFilter.closed: chiuse,
      CommissionedFilter.friends: amici,
    };

    // **Le schede vuote non si disegnano.** Una parola che non porta da nessuna
    // parte e' una porta finta, e su AMICI sarebbe pure una spia: direbbe a chi
    // non e' dei loro che qualcosa c'e'.
    final schede = [
      for (final filtro in CommissionedFilter.values)
        if (dentro[filtro]!.isNotEmpty) filtro,
    ];

    if (schede.isEmpty) {
      return const SizedBox.shrink();
    }

    // La scelta di prima puo' essersi svuotata mentre si guardava — una gara
    // che scade passa da aperte a chiuse — e allora si cade sulla prima piena.
    final scelta = schede.contains(_scelta) ? _scelta! : schede.first;
    final elenco = dentro[scelta]!;

    final righe = [
      for (final challenge in elenco)
        if (!_chiusa(challenge, now)) challenge,
    ];

    final targhe = [
      for (final challenge in elenco)
        if (_chiusa(challenge, now)) challenge,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // **Obbligatorio, non un'ottimizzazione.** Questa colonna finisce dentro
      // una `ListView`, che offre ai figli un'altezza senza limite: con la
      // misura predefinita — prendersi tutto lo spazio — non c'e' un "tutto" da
      // prendersi, e si va in errore di impaginazione.
      mainAxisSize: MainAxisSize.min,
      children: [
        // Una sola scheda piena non e' una scelta: la fila di parole sopra
        // direbbe soltanto dove ci si trova gia'.
        if (schede.length > 1) ...[
          _Filtri(
            schede: schede,
            quante: {
              for (final filtro in schede) filtro: dentro[filtro]!.length,
            },
            selected: scelta,
            onPick: (filtro) => setState(() => _scelta = filtro),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final challenge in righe) _LiveCommissionRow(challenge: challenge),
        if (righe.isNotEmpty && targhe.isNotEmpty)
          const SizedBox(height: AppSpacing.lg),
        if (targhe.isNotEmpty)
          TrophyGrid(challenges: targhe, kind: TrophyKind.commissioned),
      ],
    );
  }
}

/// La fila delle tre parole, con la stessa faccia delle schede del profilo.
class _Filtri extends StatelessWidget {
  const _Filtri({
    required this.schede,
    required this.quante,
    required this.selected,
    required this.onPick,
  });

  final List<CommissionedFilter> schede;

  /// Quante gare ci sono dentro ciascuna.
  ///
  /// **Il numero accanto alla parola non e' un ornamento.** Una fila di tre
  /// parole non dice quale vale la pena toccare, e chi cerca qualcosa le prova
  /// tutte e tre: il numero trasforma tre porte chiuse in tre porte con
  /// scritto cosa c'e' dietro.
  final Map<CommissionedFilter, int> quante;

  final CommissionedFilter selected;
  final void Function(CommissionedFilter filtro) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          for (final filtro in schede)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: GestureDetector(
                onTap: () => onPick(filtro),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          filtro.label,
                          style: texts.labelSmall?.copyWith(
                            color: filtro == selected
                                ? palette.textPrimary
                                : palette.textFaint,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '${quante[filtro] ?? 0}',
                          style: texts.labelSmall?.copyWith(
                            color: filtro == selected
                                ? palette.accent
                                : palette.textFaint,
                          ),
                        ),
                      ],
                    ),
                    // **Il filetto sotto la scelta.** Il colore da solo dice
                    // "questa e' diversa", non "questa e' quella aperta": una
                    // riga sotto la parola e' il modo in cui una scheda dice di
                    // essere una scheda, ed e' lo stesso gesto che l'app usa
                    // gia' in cima al profilo.
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 1.5,
                      width: filtro == selected ? 18 : 0,
                      color: palette.accent,
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
