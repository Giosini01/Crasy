import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              Expanded(
                child: RefreshIndicator(
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
                                    'c\'e\' in palio e quanto tempo hai.',
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
