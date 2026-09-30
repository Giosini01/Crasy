import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/followed_entry.dart';
import 'package:crasy/features/friends/presentation/widgets/suggested_drawer.dart';
import 'package:crasy/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cosa si guarda nella home: chi segui, o tutte le gare.
///
/// **Come su TikTok, due parole in cima e ferme.** GLOBALE e' la home di
/// sempre, tutte le gare aperte; SEGUITI e' dove sono in gara, adesso, le
/// persone che segui. Prima quella seconda stava nel Party sotto IN CORSO, cioe'
/// in una scheda dentro una scheda: la cosa che fa venire voglia di aprire
/// l'app — cosa stanno combinando gli altri — era la piu' difficile da trovare.
enum HomeFeed {
  followed('SEGUITI'),
  global('GLOBALE');

  const HomeFeed(this.label);

  final String label;
}

/// Quale delle due si guarda. Si apre su GLOBALE: chi non segue ancora
/// nessuno troverebbe una schermata vuota come prima cosa.
final homeFeedProvider = StateProvider<HomeFeed>((ref) => HomeFeed.global);

/// La home: le challenge aperte, una sotto l'altra.
///
/// Non e' una griglia e non sara' mai una griglia. Venti riquadri affiancati
/// sono venti cose fra cui scegliere, e mettono chi guarda nella condizione di
/// scorrere senza fermarsi. Una challenge alla volta, grande quanto lo schermo,
/// e' una cosa sola a cui rispondere si' o no.
class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(liveChallengesProvider);
    final oggi = ref.watch(dailyChallengeProvider);
    final feed = ref.watch(homeFeedProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CrasyHeaderBar(
                middle: _Lives(
                  left: ref.watch(livesLeftProvider),
                  palette: context.palette,
                ),
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // La campanella prima del piu': si guarda cosa e' successo
                    // molte volte al giorno, si lancia una challenge una volta
                    // ogni tanto. L'ordine delle icone e' l'ordine in cui si
                    // usano.
                    const NotificationBell(),
                    // **Il piu' e' rosso**, ed e' l'unica icona dell'app che lo
                    // sia.
                    //
                    // Il rosso qui dentro vuol dire premio, fiamma, attivo — e
                    // questo comando e' il gesto con cui si mettono dei soldi
                    // in palio, cioe' la cosa da cui nasce tutto il resto. Nero
                    // come le altre non si capiva a cosa servisse: sembrava un
                    // piu' qualunque in cima a una schermata piena di
                    // challenge, non il modo di lanciarne una.
                    IconButton(
                      onPressed: () => context.push(AppRoutes.create),
                      icon: Icon(
                        Icons.add_rounded,
                        color: context.palette.accent,
                      ),
                      tooltip: 'Lancia una challenge',
                    ),
                  ],
                ),
              ),
              // **Ferme, fuori da quello che scorre.** Si cambia vista da
              // qualunque punto della lista, senza tornare in cima.
              const _FeedSwitch(),
              Expanded(
                child: feed == HomeFeed.followed
                    ? const _Seguiti()
                    : RefreshIndicator(
                  color: context.palette.accent,
                  onRefresh: () async => ref.invalidate(liveChallengesProvider),
                  child: CustomScrollView(
                    slivers: [
                      // **La sfida del giorno sta prima di tutto.**
                      //
                      // Non e' una gara di CRASY: e' la gara di qualcuno messa
                      // in cima per ventiquattro ore. A mezzanotte cambia da
                      // sola.
                      //
                      // Sta in cima alla lista e non incollata allo schermo, ed
                      // e' una scelta: una scheda di gara e' alta mezzo
                      // telefono, e mezzo telefono che non si sposta mai
                      // significa scorrere la home dentro una finestrella.
                      if (oggi != null) _Daily(challenge: oggi),
                      challenges.when(
                        loading: () =>
                            const SliverToBoxAdapter(child: SizedBox.shrink()),
                        error: (_, _) => const _Message(
                          title: 'Niente da mostrare',
                          message:
                              'Non riusciamo a caricare le challenge. '
                              'Controlla la connessione e riprova.',
                        ),
                        data: (items) => items.isEmpty
                            ? const _Message(
                                title: 'Nessuna challenge aperta',
                                message:
                                    'Appena ne parte una la trovi qui, con quanto '
                                    'c\'è in palio e quanto tempo hai.',
                              )
                            : _ChallengeList(
                                // Senza la sfida del giorno, che sta gia'
                                // sopra: la stessa gara due volte nella stessa
                                // schermata fa dubitare di tutte le altre.
                                challenges: [
                                  for (final challenge in items)
                                    if (challenge.id != oggi?.id) challenge,
                                ],
                              ),
                      ),
                      // **Una riga, non le foto.** Le gare finite hanno una
                      // schermata loro: qui resta il modo di arrivarci.
                      // Mettercele dentro voleva dire appoggiare la cosa piu'
                      // importante che l'app ha da dire in coda a una lista
                      // che parla d'altro — e per giunta la leggeva solo chi
                      // scorreva fino in fondo, cioe' chi aveva gia' deciso.
                      const SliverToBoxAdapter(child: _AppenaFinite()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SEGUITI · GLOBALE, piccole e rosse sotto il marchio.
///
/// **Piccole apposta.** Sono un interruttore, non un titolo: la cosa da
/// guardare e' quello che c'e' sotto. La scelta e' rossa e piena, l'altra
/// grigia, e un trattino sotto dice dove si e'.
class _FeedSwitch extends ConsumerWidget {
  const _FeedSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scelta = ref.watch(homeFeedProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final feed in HomeFeed.values)
            GestureDetector(
              onTap: () => ref.read(homeFeedProvider.notifier).state = feed,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      feed.label,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: feed == scelta
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: feed == scelta
                            ? palette.accent
                            : palette.textFaint,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: feed == scelta ? 16 : 0,
                      height: 2,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(1),
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

/// **SEGUITI**: dove sono in gara, adesso, le persone che segui.
///
/// Una foto per riga, con sopra la gara in cui sta: da qui si da' la fiamma e
/// si entra nella gara, come dalla home di sempre.
class _Seguiti extends ConsumerWidget {
  const _Seguiti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final seguiti = ref.watch(followedIdsProvider);
    final foto = ref.watch(followedEntriesProvider);
    final problema = ref.watch(friendActivityProblemProvider);

    Widget vuoto(String titolo, String messaggio, {bool cerca = false}) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          0,
          AppSpacing.xl,
          0,
          AppSpacing.xxl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: EmptyState(title: titolo, message: messaggio),
          ),
          // **La rubrica, subito.** Chi non segue nessuno ha una cosa sola da
          // fare: trovare chi conosce. Il riquadro si apre da solo, chiede il
          // permesso ai contatti e mostra chi e' gia' qui, con Segui accanto.
          // Chi segue gia' qualcuno lo trova chiuso, a un tocco.
          const SizedBox(height: AppSpacing.md),
          SuggestedDrawer(apertoSubito: cerca),
          if (cerca) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => context.go(AppRoutes.search),
                child: Text(
                  'OPPURE CERCA PER NOME',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    final Widget corpo;

    if (seguiti.isEmpty) {
      corpo = vuoto(
        'Non segui ancora nessuno',
        'Segui chi conosci: qui vedi in quali gare sono dentro, adesso. Se ti '
            'segue anche lui siete amici, e potete sfidarvi.',
        cerca: true,
      );
    } else if (problema != null && foto.isEmpty) {
      corpo = vuoto(
        'Non riusciamo a caricare',
        'Non riusciamo a leggere dove sono in gara le persone che segui. '
            'Riprova fra poco.',
      );
    } else if (foto.isEmpty) {
      corpo = vuoto(
        'Nessuno in gara adesso',
        'Quando qualcuno che segui manda una foto a una gara aperta, la trovi '
            'qui.',
      );
    } else {
      // **Una persona, un riquadro.** Le foto arrivano dalla piu' recente; si
      // raggruppano per chi le ha mandate tenendo quell'ordine, cosi' in cima
      // resta chi ha fatto qualcosa per ultimo.
      final perPersona = <String, List<ChallengeEntry>>{};

      for (final entry in foto) {
        perPersona.putIfAbsent(entry.userId, () => []).add(entry);
      }

      final persone = perPersona.values.toList();

      corpo = ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        itemCount: persone.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: FollowedPerson(entries: persone[index]),
        ),
      );
    }

    return RefreshIndicator(
      color: palette.accent,
      onRefresh: () async {
        ref
          ..invalidate(liveChallengesProvider)
          ..invalidate(myFriendsProvider)
          ..invalidate(myFollowingProvider);
      },
      child: corpo,
    );
  }
}

/// Il modo di arrivare alle gare appena finite.
///
/// **Una scheda, non una riga di testo.** Una riga scritta in fondo a una
/// lista di gare e' indistinguibile da un pie' di pagina: si legge come una
/// nota, non come una cosa che si apre. Quello che sta dietro e' l'unica prova
/// che qui si vince davvero, e una prova deve avere l'aria di valere il tocco.
///
/// **Le facce di chi ha vinto, in miniatura.** Sono la cosa che convince, e
/// costano zero: quelle foto viaggiano gia' dentro la gara chiusa, non si
/// legge niente in piu' per mostrarle. Sovrapposte come le teste in una
/// locandina dicono in un colpo quello che la scritta direbbe in una frase —
/// *sono in tre, e hanno vinto*.
class _AppenaFinite extends ConsumerWidget {
  const _AppenaFinite();

  /// Quante facce ci stanno prima che diventino una folla illeggibile.
  static const int _quanteFacce = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;

    final vinte = [
      for (final challenge
          in ref.watch(endedChallengesProvider).valueOrNull ?? const [])
        if (challenge.hasTrophy) challenge,
    ];

    // **Finche' non ha vinto nessuno non si promette niente.** Una scheda che
    // si apre su una schermata vuota e' peggio di una scheda che non c'e'.
    if (vinte.isEmpty) {
      return const SizedBox.shrink();
    }

    final facce = vinte.take(_quanteFacce).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.recentlyEnded),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              SizedBox(
                // Ogni faccia dopo la prima sporge di diciotto: si sovrappongono
                // per meta', che e' quanto basta a leggerle tutte.
                width: 34 + (facce.length - 1) * 18,
                height: 34,
                child: Stack(
                  children: [
                    // **L'ultima disegnata sta sopra, quindi si parte dal
                    // fondo.** Al contrario, la prima faccia — quella della
                    // gara chiusa piu' di recente — finirebbe sotto tutte le
                    // altre.
                    for (var i = facce.length - 1; i >= 0; i--)
                      Positioned(
                        left: i * 18,
                        child: _FacciaVincente(url: facce[i].winnerMediaUrl),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'APPENA FINITE',
                      style: texts.labelSmall?.copyWith(
                        color: palette.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vinte.length == 1
                          ? 'Uno si è preso i soldi'
                          : '${vinte.length} si sono presi i soldi',
                      style: texts.titleSmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// La foto che ha vinto, dentro un cerchio con il bordo del colore della
/// pagina: e' quel bordo a staccarla da quella che le sta sotto.
class _FacciaVincente extends StatelessWidget {
  const _FacciaVincente({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surfaceMuted,
        border: Border.all(color: palette.background, width: 2),
      ),
      child: ClipOval(
        // **Senza foto, la coppa.** Il cerchio grigio che restava quando la
        // foto non arrivava — un video, una foto gia' tolta — sembrava
        // un'immagine rotta. La coppa rossa dice la stessa cosa della foto:
        // qui qualcuno ha vinto.
        child: url.isEmpty
            ? _Coppa(palette: palette)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    _Coppa(palette: palette),
              ),
      ),
    );
  }
}

class _Coppa extends StatelessWidget {
  const _Coppa({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.accentTint,
      child: Center(
        child: Icon(Icons.emoji_events, size: 18, color: palette.accent),
      ),
    );
  }
}

/// Le partecipazioni che restano oggi: cinque macchine fotografiche e basta.
///
/// **Cinque al giorno, e poi si aspetta domani.** Senza un tetto, l'unica
/// strategia che paga e' partecipare a tutto: venti scatti fatti male sperando
/// che uno prenda delle fiamme per caso. Con cinque in mano bisogna scegliere a
/// quali gare si tiene davvero.
///
/// **Senza scritte.** Una riga come "puoi partecipare ad altre tre oggi" dice
/// la stessa cosa dei disegni ma occupa l'intestazione, e in cima a una
/// schermata lo spazio e' l'unica valuta che c'e'. Cinque sagome che si
/// spengono una alla volta sono un contatore che si legge senza leggere: quante
/// sono rosse, quante grigie. La frase resta comunque raggiungibile — si tiene
/// il dito sopra, o si tocca — per chi la prima volta non capisce cosa siano.
class _Lives extends StatelessWidget {
  const _Lives({required this.left, required this.palette});

  final int left;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final frase = left == 0
        ? 'Hai finito le partecipazioni di oggi: domani ricominci da cinque.'
        : 'Puoi partecipare ad altre $left gare oggi.';

    return Tooltip(
      message: frase,
      child: Semantics(
        label: frase,
        excludeSemantics: true,
        child: GestureDetector(
          // Toccarle non porta da nessuna parte: dice cosa sono. E' la sola
          // spiegazione rimasta dopo aver tolto la scritta, e senza di essa
          // cinque disegnini in cima allo schermo restano un mistero.
          onTap: () => ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(frase))),
          behavior: HitTestBehavior.opaque,
          // **Cinque fotocamere, non una fotocamera e un numero.**
          //
          // Un numero si legge; cinque disegnini si *vedono*, ed e' una cosa
          // diversa. Quello che conta qui non e' sapere che ne restano tre: e'
          // accorgersi, senza leggere niente, che ne restano poche — e due
          // sagome vuote in fondo alla fila lo dicono in un colpo d'occhio,
          // mentre "3" va letto e confrontato con un cinque che nessuno ha
          // scritto.
          //
          // Quella spesa diventa il contorno vuoto e non solo grigia: il colore
          // da solo non basta a chi non lo distingue, e la forma piena contro
          // quella vuota si vede comunque.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < Challenge.livesPerDay; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i < left
                        ? Icons.photo_camera_rounded
                        : Icons.photo_camera_outlined,
                    size: 16,
                    color: i < left ? palette.accent : palette.line,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La sfida del giorno: una riga rossa, la gara, e un filetto che la stacca.
///
/// **Perche' esiste.** Un'app che si ricorda si apre quando uno se ne ricorda,
/// e nessuno se ne ricorda tutti i giorni. Un appuntamento fisso — una sfida
/// sola, uguale per tutti, che cambia a mezzanotte — e' l'unica cosa che
/// trasforma "ci penso" in "guardo cosa c'e' oggi".
///
/// **Il premio non lo mette CRASY.** La gara e' di chi l'ha lanciata, e in cima
/// ci sale per un giorno. Una societa' che promette un premio fa un concorso a
/// premi — comunicazione al ministero, cauzione, verbale, ritenuta — e non e'
/// una cosa che si fa per sbaglio in una schermata. Qui non si promette niente
/// a nessuno: si mette in evidenza la gara di un altro.
class _Daily extends StatelessWidget {
  const _Daily({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // **Cerchiata di rosso.** In una lista in cui ogni gara comincia
            // con una cifra rossa, il rosso da solo non la distingue piu': e'
            // il colore di tutta la schermata. La cornice si', perche' e'
            // l'unica cosa dell'app che ha un bordo attorno — e un bordo dice
            // "questo blocco e' un'altra cosa" prima che uno legga una parola.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: palette.accent, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SFIDA DEL GIORNO',
                        style: texts.labelSmall?.copyWith(
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      // Quanto manca alla prossima, non alla fine della gara:
                      // sono due orologi diversi, e qui conta il primo — dice
                      // fra quanto questa esce dalla cima.
                      Expanded(
                        child: Text(
                          'cambia a mezzanotte',
                          style: texts.labelSmall?.copyWith(
                            color: palette.textFaint,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (challenge.isDaily) ...[
                    const SizedBox(height: AppSpacing.xs),
                    // **Le due cose che la rendono diversa, scritte.** Che sia
                    // gratis si vede dalla parola al posto della cifra; che non
                    // costi una delle cinque non si vede da nessuna parte, e
                    // senza saperlo chi ne ha una sola in mano non la spende
                    // qui — che e' esattamente il contrario di quello per cui
                    // esiste.
                    Text(
                      'Gratis, e non ti toglie una delle cinque di oggi.',
                      style: texts.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  ChallengeCard(
                    challenge: challenge,
                    onOpen: () =>
                        context.push(AppRoutes.challengeDetailOf(challenge.id)),
                    onParticipate: () =>
                        context.push(AppRoutes.participateOf(challenge.id)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Divider(color: palette.line),
          ],
        ),
      ),
    );
  }
}

/// Un messaggio al posto delle challenge, con lo stesso margine laterale che
/// avrebbero avuto loro.
class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      sliver: SliverToBoxAdapter(
        child: EmptyState(title: title, message: message),
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  const _ChallengeList({required this.challenges});

  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.section,
      ),
      sliver: SliverList.separated(
        itemCount: challenges.length,
        // Fra una missione e l'altra: spazio, un filetto, altro spazio.
        //
        // Lo spazio da solo non bastava. Ogni challenge finisce con una foto e
        // comincia con un premio, e senza un segno in mezzo il premio della
        // seconda sembrava appartenere alla foto della prima. Il filetto e' da
        // mezzo pixel — dice "qui finisce" e nient'altro.
        separatorBuilder: (context, index) => Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            Divider(color: context.palette.line),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
        itemBuilder: (context, index) {
          final challenge = challenges[index];

          return ChallengeCard(
            challenge: challenge,
            onOpen: () =>
                context.push(AppRoutes.challengeDetailOf(challenge.id)),
            onParticipate: () =>
                context.push(AppRoutes.participateOf(challenge.id)),
          );
        },
      ),
    );
  }
}
