import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
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

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.palette.accent,
            onRefresh: () async => ref.invalidate(liveChallengesProvider),
            child: CustomScrollView(
              slivers: [
                const _Header(),
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
                      : _ChallengeList(challenges: items),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// L'intestazione: marchio, macchine fotografiche, comandi. **E resta li'.**
///
/// Prima scorreva via con la lista. Adesso e' incollata in alto, e il motivo e'
/// quello che ci sta in mezzo: le partecipazioni rimaste oggi. Un tetto che si
/// vede solo tornando in cima non serve a niente — la decisione su quali gare
/// valgono la pena si prende **mentre si scorre**, guardando questa qui.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderBar(
        left: ref.watch(livesLeftProvider),
        palette: context.palette,
      ),
    );
  }
}

class _HeaderBar extends SliverPersistentHeaderDelegate {
  const _HeaderBar({required this.left, required this.palette});

  final int left;
  final AppPalette palette;

  static const double _top = AppSpacing.md;
  static const double _bottom = AppSpacing.sm;
  static const double _height = CrasyHeader.height + _top + _bottom;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // **Il riquadro riempie tutta l'altezza dichiarata.** Lasciato libero si
    // stringe sul contenuto, e una striscia che occupa meno spazio di quello
    // che ha chiesto lascia passare le foto sotto il proprio fondo.
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Il fondo **deve** essere pieno: da fermo e' invisibile perche' e'
          // lo stesso colore della pagina, ma mentre si scorre e' l'unica cosa
          // che impedisce alle foto di passarci attraverso.
          color: palette.background,
          // Il filetto compare solo quando qualcosa sta scorrendo sotto. Da
          // fermo separerebbe due cose che sono la stessa cosa; in movimento
          // dice dove finisce quello che resta e dove comincia quello che va.
          border: overlapsContent
              ? Border(bottom: BorderSide(color: palette.line, width: 0.5))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            _top,
            AppSpacing.page - AppSpacing.xs,
            _bottom,
          ),
          child: CrasyHeader(
            middle: _Lives(left: left, palette: palette),
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // La campanella prima del piu': si guarda cosa e' successo
                // molte volte al giorno, si lancia una challenge una volta ogni
                // tanto. L'ordine delle due icone e' l'ordine in cui si usano.
                const NotificationBell(),
                // **Il piu' e' rosso**, ed e' l'unica icona dell'app che lo sia.
                //
                // Il rosso qui dentro vuol dire premio, fiamma, attivo — e
                // questo comando e' il gesto con cui si mettono dei soldi in
                // palio, cioe' la cosa da cui nasce tutto il resto. Nero come le
                // altre non si capiva a cosa servisse: sembrava un piu'
                // qualunque in cima a una schermata piena di challenge, non il
                // modo di lanciarne una.
                IconButton(
                  onPressed: () => context.push(AppRoutes.create),
                  icon: Icon(Icons.add_rounded, color: palette.accent),
                  tooltip: 'Lancia una challenge',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderBar old) =>
      old.left != left || old.palette != palette;
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < Challenge.livesPerDay; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    // Quella spesa diventa il contorno vuoto, non solo grigia:
                    // il colore da solo non basta a chi non lo distingue, e la
                    // forma piena contro la forma vuota si vede comunque.
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
