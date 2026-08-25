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
                const _Lives(),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page - AppSpacing.xs,
        AppSpacing.xl,
      ),
      sliver: SliverToBoxAdapter(
        child: CrasyHeader(
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // La campanella prima del piu': si guarda cosa e' successo molte
              // volte al giorno, si lancia una challenge una volta ogni tanto.
              // L'ordine delle due icone e' l'ordine in cui si usano.
              const NotificationBell(),
              // **Il piu' e' rosso**, ed e' l'unica icona dell'app che lo sia.
              //
              // Il rosso qui dentro vuol dire premio, fiamma, attivo — e questo
              // comando e' il gesto con cui si mettono dei soldi in palio, cioe'
              // la cosa da cui nasce tutto il resto. Nero come le altre non si
              // capiva a cosa servisse: sembrava un piu' qualunque in cima a una
              // schermata piena di challenge, non il modo di lanciarne una.
              IconButton(
                onPressed: () => context.push(AppRoutes.create),
                icon: Icon(Icons.add_rounded, color: context.palette.accent),
                tooltip: 'Lancia una challenge',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le partecipazioni che restano oggi.
///
/// **Cinque al giorno, e poi si aspetta domani.** Senza un tetto, l'unica
/// strategia che paga e' partecipare a tutto: venti scatti fatti male sperando
/// che uno prenda delle fiamme per caso. Con cinque in mano bisogna scegliere a
/// quali gare si tiene davvero.
///
/// **Resta incollata in cima mentre si scorre, e non sparisce mai.** Prima si
/// nascondeva quando erano tutte e cinque intatte, con l'idea che a inizio
/// giornata non ci fosse niente da sapere. Era sbagliato, e per due motivi.
/// Il primo: un tetto che si vede solo quando lo stai gia' consumando arriva
/// sempre tardi — la scelta di quali gare valgono la pena si fa **prima** di
/// bruciare la prima. Il secondo: le gare si guardano scorrendo, e una riga in
/// cima alla lista, dopo due schermate, e' come se non ci fosse. Quando decidi
/// se partecipare a questa qui, il numero deve essere ancora sotto gli occhi.
///
/// Il prezzo e' una striscia di quaranta pixel che sta li' sempre, ed e' un
/// prezzo giusto: e' l'unica cosa in tutta l'app che dice quanto ti resta.
class _Lives extends ConsumerWidget {
  const _Lives();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LivesBar(
        left: ref.watch(livesLeftProvider),
        palette: context.palette,
        text: context.texts.labelSmall,
      ),
    );
  }
}

/// La striscia vera e propria, con il fondo pieno.
///
/// Il fondo **deve** essere opaco: da fermo e' invisibile perche' e' lo stesso
/// colore della pagina, ma mentre si scorre e' l'unica cosa che impedisce alle
/// foto delle gare di passarci attraverso.
class _LivesBar extends SliverPersistentHeaderDelegate {
  const _LivesBar({
    required this.left,
    required this.palette,
    required this.text,
  });

  final int left;
  final AppPalette palette;
  final TextStyle? text;

  /// Quanto e' alta: una riga da undici punti, le sue icone, e l'aria intorno.
  static const double _height = 40;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final finite = left == 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        // Il filetto compare **solo quando qualcosa le sta scorrendo sotto**.
        // Da fermo separerebbe due cose che sono la stessa cosa; in movimento
        // dice dove finisce quello che resta li' e dove comincia quello che
        // scorre.
        border: overlapsContent
            ? Border(bottom: BorderSide(color: palette.line, width: 0.5))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Row(
          children: [
            for (var i = 0; i < Challenge.livesPerDay; i++)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(
                  i < left
                      ? Icons.photo_camera_rounded
                      : Icons.photo_camera_outlined,
                  size: 14,
                  color: i < left ? palette.accent : palette.line,
                ),
              ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              finite
                  ? 'FINITE PER OGGI, DOMANI RICOMINCI'
                  : 'PUOI PARTECIPARE AD ALTRE $left OGGI',
              style: text?.copyWith(
                color: finite ? palette.textFaint : palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_LivesBar old) =>
      old.left != left || old.palette != palette || old.text != text;
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
        AppSpacing.md,
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
