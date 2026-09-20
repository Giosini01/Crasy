import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/media_gestures.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/leaderboard.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Chi ha vinto.
///
/// E' la schermata che rende vero tutto il resto: se le challenge finiscono e
/// non si vede mai nessuno vincere, il premio in palio resta una promessa.
/// Per questo qui il premio si scrive al passato — **vinti**, non "in palio" —
/// e accanto c'e' il nome di una persona.
/// Quale delle tre si sta guardando. Fuori dalla schermata perche' deve
/// sopravvivere a chi esce e rientra dalla scheda.
final trendViewProvider = StateProvider<TrendView>((ref) => TrendView.winners);

class WinnersPage extends ConsumerWidget {
  const WinnersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(endedChallengesProvider);
    final view = ref.watch(trendViewProvider);
    final chiuse = challenges.valueOrNull ?? const <Challenge>[];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Il logotipo al posto del titolo. Questa schermata e' la
              // vetrina della promessa — qualcuno ha vinto davvero — ed e' il
              // posto giusto perche' il marchio ci metta la faccia.
              const CrasyHeaderBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  children: [
                    HighlightedText(
                      switch (view) {
                        TrendView.winners =>
                          'Chi si è preso più soldi, adesso.',
                        TrendView.launchers =>
                          'Chi ne ha messi di più in palio.',
                        TrendView.fresh =>
                          'Le challenge chiuse, e chi si è preso i soldi.',
                      },
                      highlight: switch (view) {
                        TrendView.winners => 'più soldi',
                        TrendView.launchers => 'in palio',
                        TrendView.fresh => 'chi si è preso i soldi',
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Switch(selected: view),
                    const SizedBox(height: AppSpacing.xl),
                    if (view != TrendView.fresh)
                      _Classifica(
                        righe: view == TrendView.winners
                            ? Leaderboard.winners(chiuse)
                            : Leaderboard.launchers(chiuse),
                        vuota: view == TrendView.winners
                            ? 'Quando qualcuno vince una gara con dei soldi in '
                                  'palio, il podio si riempie da solo.'
                            : 'Quando qualcuno lancia una gara mettendoci dei '
                                  'soldi, lo trovi qui.',
                      )
                    else
                      challenges.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const EmptyState(
                          title: 'Non disponibile',
                          message:
                              'Non riusciamo a caricare le challenge concluse. '
                              'Controlla la connessione.',
                        ),
                        data: (items) => _Winners(challenges: items),
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

/// Le gare finite che vale la pena mostrare.
///
/// **Quelle a cui non ha partecipato nessuno non si vedono.** Una challenge
/// senza foto non ha niente da raccontare: non c'e' un vincitore, non c'e'
/// un'immagine, e resta una riga che dice "non ha partecipato nessuno" in mezzo
/// a chi ha vinto dei soldi. Su una schermata che esiste per rendere credibile
/// la promessa, e' esattamente il contrario di quello che serve.
///
/// Sparire dalla vista non vuol dire sparire dai conti: quelle gare vengono
/// **chiuse lo stesso** — e' cosi' che il premio torna a chi l'aveva messo — ma
/// a chiuderle e' il server, non questa schermata. Poco dopo le cancella.
class _Winners extends StatelessWidget {
  const _Winners({required this.challenges});

  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    final withPeople = [
      for (final challenge in challenges)
        if (challenge.participantsCount > 0 && challenge.winnerEntryId != '')
          challenge,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (withPeople.isEmpty)
          const EmptyState(
            title: 'Nessuna challenge conclusa',
            message:
                'Quando la prima challenge si chiude, qui trovi chi ha vinto e '
                'quanto.',
          )
        else
          for (final challenge in withPeople) ...[
            _WinnerBlock(challenge: challenge),
            const SizedBox(height: AppSpacing.section),
          ],
      ],
    );
  }
}

class _WinnerBlock extends ConsumerWidget {
  const _WinnerBlock({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final winnerId = challenge.winnerEntryId;
    final entries =
        ref.watch(challengeEntriesProvider(challenge.id)).valueOrNull ??
        const <ChallengeEntry>[];

    final winner = winnerId == null || winnerId.isEmpty
        ? null
        : entries.where((entry) => entry.id == winnerId).firstOrNull;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.challengeDetailOf(challenge.id)),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.prizeLabel,
                  style: texts.displayMedium?.copyWith(color: palette.accent),
                ),
              ),
              Text(
                challenge.scopeLabel,
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(challenge.title.toUpperCase(), style: texts.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          if (winnerId != null && winnerId.isEmpty)
            Text(
              'Non ha partecipato nessuno. Il premio torna a chi l\'ha messo.',
              style: texts.bodyMedium,
            )
          else if (winner == null)
            Text('Vincitore in arrivo.', style: texts.bodyMedium)
          else ...[
            // **Solo la foto del vincitore.** Le altre stanno dentro la gara,
            // per chi vuole andarle a rivedere; qui si racconta come e' finita,
            // e come e' finita e' una foto sola.
            MediaTap(
              onTap: () => FullscreenMedia.open(
                context,
                entries: [winner],
                entry: winner,
              ),
              child: MediaFrame(
                // A tutta larghezza: l'originale.
                url: winner.mediaUrl,
                video: winner.isVideo,
                aspectRatio: 1,
                // **Il nome non sta sulla foto.** Ce l'ha gia' la riga qui
                // sotto, dove sta dentro una frase che dice anche quanto ha
                // vinto e con quante fiamme: scritto anche sull'immagine e' la
                // stessa parola due volte a due dita di distanza, e per giunta
                // copre la cosa che si e' venuti a guardare.
                // **Quante fiamme ha preso, sopra la foto.**
                //
                // Durante la gara i numeri sono nascosti apposta: sapere come
                // sta andando cambia come si vota, e una gara in cui si vota
                // guardando la classifica non e' piu' una gara. Ma qui la gara
                // e' finita, le fiamme sono quelle e non si toccano piu' — e
                // allora e' l'unica cosa che manca per capire *come* ha vinto.
                // Due fiamme e ottanta fiamme sono la stessa vittoria scritta
                // in due modi molto diversi, e chi guarda ha il diritto di
                // saperlo.
                overlay: _Fiamme(quante: winner.votes),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '@${winner.authorName}',
                    style: texts.titleMedium,
                  ),
                  TextSpan(
                    // Il numero anche qui, scritto: sulla foto e' un
                    // distintivo che si guarda, nella frase e' una cosa che si
                    // legge — e sono i due modi in cui la gente prende
                    // un'informazione. A zero resta la frase di prima: le gare
                    // chiuse quando il conteggio non finiva ancora dentro il
                    // documento non hanno quel numero, e scrivere "con 0
                    // fiamme" sotto una vittoria sarebbe una bugia.
                    text: winner.votes > 0
                        ? ' ha vinto ${challenge.prizeLabel} con '
                              '${winner.votes} '
                              '${winner.votes == 1 ? 'fiamma' : 'fiamme'}'
                        : ' ha vinto ${challenge.prizeLabel} con più fiamme',
                    style: texts.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Il numero di fiamme, appoggiato sull'angolo della foto vincitrice.
///
/// **Si legge su qualunque foto.** Un numero bianco su una foto chiara non si
/// vede, e questa e' l'unica cosa della schermata che deve leggersi sempre:
/// sotto c'e' una pastiglia scura, che e' il modo piu' semplice di non
/// dipendere da cosa c'e' nell'immagine.
class _Fiamme extends StatelessWidget {
  const _Fiamme({required this.quante});

  final int quante;

  @override
  Widget build(BuildContext context) {
    // A zero non si scrive niente: le gare chiuse prima che il conteggio
    // finisse dentro il documento non ce l'hanno, e uno zero li' direbbe "non
    // e' piaciuta a nessuno" di una foto che magari aveva vinto a mani basse.
    if (quante <= 0) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 15,
                  color: context.palette.accent,
                ),
                const SizedBox(width: 3),
                Text(
                  '$quante',
                  style: context.texts.labelMedium?.copyWith(
                    color: Colors.white,
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

/// Cosa si guarda nella scheda di chi sta andando forte.
///
/// **Tre cose, e sono tre domande diverse.** Chi sta vincendo, chi sta facendo
/// giocare, e cos'e' appena successo. Messe una sotto l'altra sarebbero una
/// lista lunga in cui non si capisce dove finisce una e comincia l'altra: tre
/// parole in cima e una sola sotto gli occhi.
enum TrendView {
  /// Chi ha portato a casa piu' soldi.
  winners('VINCITORI'),

  /// Chi ne ha messi di piu' in palio.
  launchers('CHI FA GIOCARE'),

  /// Le gare appena chiuse, con la foto che ha vinto.
  fresh('APPENA FINITE');

  const TrendView(this.label);

  final String label;
}
/// I tre metalli, ognuno con la sua faccia: il fronte, il piano di sopra, il
/// fianco in ombra e il colore del numero.
///
/// **Quattro toni e non uno.** Un blocco di un colore solo e' un rettangolo
/// colorato; quello che lo rende un oggetto e' che le sue tre facce prendono la
/// luce in modo diverso — il piano di sopra guarda la lampada ed e' il piu'
/// chiaro, il fronte sta in mezzo, il fianco e' girato via ed e' il piu' scuro.
class _Metallo {
  const _Metallo({
    required this.alto,
    required this.fronteChiaro,
    required this.fronteScuro,
    required this.fianco,
    required this.numero,
  });

  final Color alto;
  final Color fronteChiaro;
  final Color fronteScuro;
  final Color fianco;
  final Color numero;

  static const oro = _Metallo(
    alto: Color(0xFFFFE9A3),
    fronteChiaro: Color(0xFFF6CE5C),
    fronteScuro: Color(0xFFD9A62A),
    fianco: Color(0xFFB98A1E),
    numero: Color(0xFF7A5A0E),
  );

  static const argento = _Metallo(
    alto: Color(0xFFF4F4F7),
    fronteChiaro: Color(0xFFDDDDE4),
    fronteScuro: Color(0xFFB9B9C4),
    fianco: Color(0xFF9E9EAA),
    numero: Color(0xFF63636E),
  );

  static const bronzo = _Metallo(
    alto: Color(0xFFF0C9A8),
    fronteChiaro: Color(0xFFDDA274),
    fronteScuro: Color(0xFFB87848),
    fianco: Color(0xFF9A6138),
    numero: Color(0xFF6B4023),
  );

  static const List<_Metallo> tutti = [oro, argento, bronzo];
}

/// **Il podio.**
///
/// Tre gradini e non un elenco numerato, per una ragione sola: un elenco si
/// legge dall'alto in basso e il primo e' soltanto la riga piu' in alto. Un
/// podio si guarda tutto insieme, e **il primo e' piu' alto degli altri** — la
/// differenza si vede prima di leggere qualunque numero.
///
/// L'ordine e' quello vero: secondo, primo, terzo. Non e' un vezzo — e' dove
/// l'occhio si aspetta di trovarli, e metterli in fila uno-due-tre farebbe
/// sembrare il primo semplicemente quello a sinistra.
///
/// **I tre blocchi si toccano, e stanno su una pedana sola.** Staccati erano
/// tre colonne vicine, e un podio fatto di pezzi separati non e' un podio: e'
/// un grafico a barre. Quello che lo tiene insieme e' la base che ci passa
/// sotto tutta intera — la stessa cosa che, su un podio vero, si sale.
class _Podio extends StatelessWidget {
  const _Podio({required this.righe});

  final List<LeaderRow> righe;

  /// Quanto e' alto ogni gradino. Le proporzioni sono quelle di un podio vero:
  /// il primo ha quasi il doppio del terzo.
  static const Map<int, double> _altezze = {1: 104, 2: 76, 3: 56};

  @override
  Widget build(BuildContext context) {
    // Sotto i tre, un podio non e' un podio: con due gradini il terzo posto
    // vuoto si legge come un errore di caricamento. Si mostra quello che c'e'.
    final posti = <int>[
      if (righe.length > 1) 1,
      0,
      if (righe.length > 2) 2,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final posto in posti)
              Expanded(
                child: _Gradino(
                  riga: righe[posto],
                  posto: posto + 1,
                  altezza: _altezze[posto + 1]!,
                ),
              ),
          ],
        ),
        // **La pedana.** Corre sotto tutti e tre e sporge di poco ai lati: e'
        // quella a dire che i gradini sono un oggetto solo. Il filo chiaro
        // sopra e' il suo spigolo, il piano su cui i blocchi appoggiano.
        Container(
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6E6EB), Color(0xFFBDBDC8), Color(0xFF9A9AA6)],
              stops: [0, 0.35, 1],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
        // **Il filo rosso sotto il podio.** Un podio d'oro e d'argento e' un
        // podio qualunque: questa riga e' la firma dell'app sotto, ed e' la
        // stessa cosa che fa un marchio stampato sul bordo di un palco vero.
        const SizedBox(height: 3),
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                context.palette.accent.withValues(alpha: 0),
                context.palette.accent,
                context.palette.accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Un gradino: chi ci sta sopra, e il blocco su cui sta.
class _Gradino extends StatelessWidget {
  const _Gradino({
    required this.riga,
    required this.posto,
    required this.altezza,
  });

  final LeaderRow riga;
  final int posto;
  final double altezza;

  /// Quanto e' spesso il piano di sopra del blocco. E' la faccia che si vede
  /// guardando da appena sopra, ed e' tutto il tre‑di.
  static const double _spessore = 9;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final metallo = _Metallo.tutti[posto - 1];
    final grande = posto == 1;

    return GestureDetector(
      onTap: riga.userId.isEmpty
          ? null
          : () => context.push(AppRoutes.userProfileOf(riga.userId)),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // **Il primo ha il fuoco dietro.** L'oro dice gia' che e' il primo,
          // ma l'oro e' il colore del podio e non dell'app: questo alone e' il
          // rosso di CRASY che si vede solo qui, su una faccia sola, e serve a
          // far capire in un colpo dove guardare.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: grande
                  ? [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: FriendAvatar(
              userId: riga.userId,
              username: riga.username,
              size: grande ? 54 : 42,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '@${riga.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: texts.labelSmall?.copyWith(color: palette.textSecondary),
            ),
          ),
          // La cifra e' la cosa piu' grande sopra il blocco: e' quella che fa
          // la classifica, e deve leggersi prima del nome.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppMoney.format(riga.cents),
              style: (grande ? texts.titleMedium : texts.labelMedium)?.copyWith(
                color: palette.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: altezza,
            child: Stack(
              children: [
                // Il fronte del blocco.
                Positioned.fill(
                  top: _spessore,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          metallo.fronteChiaro,
                          metallo.fronteScuro,
                          metallo.fianco,
                        ],
                        stops: const [0, 0.72, 1],
                      ),
                    ),
                  ),
                ),
                // **Il piano di sopra**, piu' chiaro: e' la faccia che guarda
                // la luce, ed e' l'unica cosa che distingue un blocco da un
                // rettangolo. Senza, il podio e' piatto come un disegno.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _spessore,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: metallo.alto,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
                // L'ombra che il blocco piu' alto getta su quello accanto. Sul
                // primo non c'e': niente lo sovrasta.
                if (!grande)
                  Positioned(
                    top: _spessore,
                    bottom: 0,
                    width: 10,
                    left: posto == 2 ? null : 0,
                    right: posto == 2 ? 0 : null,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: posto == 2
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          end: posto == 2
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                // Il numero, dentro il blocco e grande: e' il segno che si
                // legge da lontano, prima del nome e prima della cifra.
                Positioned.fill(
                  top: _spessore,
                  child: Center(
                    child: Text(
                      '$posto',
                      style: texts.displaySmall?.copyWith(
                        color: metallo.numero,
                        fontSize: grande ? 34 : 27,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.45),
                            offset: const Offset(0, 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dal quarto in giu': una riga per uno, senza medaglie.
///
/// **Trasparente, e il rosso solo dove serve.** Le tessere piene erano
/// cinquanta rettangoli grigi in fila: tanta grafica per dire una cosa sola,
/// e quella cosa — chi sta sopra chi — l'ordine la diceva gia' da se'. Qui non
/// c'e' nessun riempimento, c'e' la pagina che si vede attraverso e un filo
/// sotto ogni riga. Quello che resta a fare il lavoro e' il rosso dell'app:
/// il numero di posizione e la cifra, cioe' esattamente le due cose per cui
/// uno apre una classifica.
///
/// **E la propria riga si accende.** Una classifica risponde a due domande —
/// chi sta davanti, e dove sto io — e la seconda senza un segno costringe a
/// leggere cinquanta nomi cercando il proprio. E' l'unica riga con un velo di
/// colore addosso: si trova prima di aver letto niente.
class _RigaClassifica extends ConsumerWidget {
  const _RigaClassifica({required this.riga, required this.posto});

  final LeaderRow riga;
  final int posto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final sonoIo = riga.userId.isNotEmpty
        && riga.userId == ref.watch(currentUserIdProvider);

    return GestureDetector(
      onTap: riga.userId.isEmpty
          ? null
          : () => context.push(AppRoutes.userProfileOf(riga.userId)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          // Il velo rosso c'e' su una riga sola in tutta la schermata, ed e'
          // quello che la fa trovare scorrendo.
          color: sonoIo ? palette.accentTint : Colors.transparent,
          borderRadius: sonoIo
              ? BorderRadius.circular(AppRadius.sm)
              : BorderRadius.zero,
          // Il filo che separa: sotto la propria riga non serve, ce l'ha gia'
          // il velo a dire dove finisce.
          border: sonoIo
              ? null
              : Border(bottom: BorderSide(color: palette.line)),
        ),
        child: Row(
          children: [
            // **Il numero e' rosso, ed e' la prima cosa della riga.** E' la
            // posizione: il motivo per cui questa schermata esiste.
            SizedBox(
              width: 30,
              child: Text(
                '$posto',
                textAlign: TextAlign.center,
                style: texts.labelMedium?.copyWith(color: palette.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FriendAvatar(
              userId: riga.userId,
              username: riga.username,
              size: 32,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Il nome sopra, le gare sotto. Affiancati si contendevano lo
            // spazio con la cifra, e su un nome lungo qualcosa finiva
            // tagliato. Incolonnati ci stanno sempre tutti e due, e il conto
            // delle gare torna a essere quello che e': una precisazione, non
            // un dato alla pari.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sonoIo ? '@${riga.username} · tu' : '@${riga.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texts.labelMedium?.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    riga.count == 1 ? '1 gara' : '${riga.count} gare',
                    style: texts.labelSmall?.copyWith(color: palette.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // La cifra e' la cosa che fa la classifica: rossa anche lei, ed e'
            // in fondo perche' e' li' che l'occhio arriva dopo il nome.
            Text(
              AppMoney.format(riga.cents),
              style: texts.titleSmall?.copyWith(color: palette.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una classifica intera: il podio e la coda.
class _Classifica extends StatelessWidget {
  const _Classifica({required this.righe, required this.vuota});

  /// Fin dove arriva l'elenco sotto il podio.
  ///
  /// **Cinquanta, e non tutte.** Una classifica serve a rispondere a due
  /// domande — chi sta davanti, e dove sto io — e per la seconda cinquanta
  /// righe bastano: chi e' oltre il cinquantesimo non ha bisogno del numero
  /// preciso, ha bisogno di sapere che non c'e' ancora. Senza un tetto,
  /// l'elenco cresce quanto le gare chiuse e si scorre a vuoto — ed e' il modo
  /// piu' sicuro di far smettere di guardarla.
  static const int _quanti = 50;

  final List<LeaderRow> righe;

  /// Cosa dire quando non c'e' ancora nessuno.
  final String vuota;

  @override
  Widget build(BuildContext context) {
    if (righe.isEmpty) {
      return EmptyState(title: 'Ancora niente', message: vuota);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Podio(righe: righe),
        if (righe.length > 3) ...[
          const SizedBox(height: AppSpacing.xl),
          // **Una parola sopra l'elenco.** Senza, le tessere sembrano
          // continuare il podio e il quarto posto pare un gradino mancato.
          // Con, si capisce che li' comincia un'altra cosa: la coda.
          Text(
            'DAL QUARTO IN GIÙ',
            style: context.texts.labelSmall?.copyWith(
              color: context.palette.textFaint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 3; i < righe.length && i < _quanti; i++)
            _RigaClassifica(riga: righe[i], posto: i + 1),
        ],
      ],
    );
  }
}

/// La fila delle tre parole in cima.
///
/// Stessa faccia di quelle del party e del profilo: **un'app non insegna due
/// volte lo stesso gesto**. Chi ha gia' capito come si cambia scheda fra gli
/// amici qui non deve capire niente di nuovo.
class _Switch extends ConsumerWidget {
  const _Switch({required this.selected});

  final TrendView selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final view in TrendView.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: GestureDetector(
                onTap: () => ref.read(trendViewProvider.notifier).state = view,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.label,
                      style: context.texts.labelSmall?.copyWith(
                        color: view == selected
                            ? palette.textPrimary
                            : palette.textFaint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Il filetto sotto la scelta: il colore da solo dice
                    // "questa e' diversa", non "questa e' quella aperta".
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 1.5,
                      width: view == selected ? 20 : 0,
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
