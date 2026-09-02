import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La campanella.
///
/// Un elenco e basta: chi ha fatto cosa, quando, e dove porta. Non ci sono
/// sezioni, non c'e' "oggi" e "questa settimana", non c'e' niente da
/// archiviare — sono poche righe che si leggono in tre secondi e poi non
/// servono piu'.
///
/// Si segna tutto come visto **aprendo la pagina**, non riga per riga. Chi apre
/// la campanella le ha viste: chiedergli anche di toccarne una per volta
/// sarebbe dargli un lavoro per un problema che non ha.
///
/// ## Come e' fatta una riga
///
/// Tre cose, in quest'ordine di importanza: **chi**, **cosa**, **quando**.
///
/// La faccia e' grande — quanto un pollice — perche' e' l'unica parte della
/// riga che si riconosce senza leggere: si scorre la campanella cercando una
/// persona, non una frase. Sopra la faccia, in basso a destra, c'e' un tondino
/// che dice **di che notizia si tratta**: la fiamma, la coppa, la fotocamera,
/// la persona. E' quello che permette di capire una riga con un colpo d'occhio
/// invece di leggerla.
///
/// Il rosso compare in tre posti soltanto, e sono i tre di sempre:
///
/// - **la fiamma e la coppa**, cioe' voti e premi;
/// - **il velo dietro le righe non lette**, che e' cio' che e' attivo — la
///   ragione per cui uno ha aperto questa schermata;
/// - **il pallino** a destra di quelle righe.
///
/// Una partecipazione e una richiesta di amicizia hanno il tondino nero: sono
/// notizie, non fuoco. Se fosse rosso tutto, il rosso smetterebbe di dire
/// qualcosa gia' alla terza riga.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  /// L'ultima occhiata **di prima di questa**.
  ///
  /// **Va congelata appena si entra, o i numeri spariscono mentre li guardi.**
  /// Aprendo questa schermata si segna tutto come visto — e' giusto, altrimenti
  /// il pallino rosso sulla campanella non si spegnerebbe mai — ma da quel
  /// momento "non lette" diventa zero, e i conti accanto alle quattro sezioni
  /// si azzerano nello stesso istante in cui uno li sta leggendo.
  ///
  /// Tenendo il valore di quando si e' entrati, i numeri restano quelli che
  /// erano sulla campanella un secondo prima: e' quello che si e' venuti a
  /// vedere.
  DateTime? _apertoCon;
  bool _congelato = false;

  /// Se la sezione di partenza e' gia' stata scelta.
  bool _sezioneScelta = false;

  @override
  void initState() {
    super.initState();

    // Dopo la prima frame, non durante: qui si scrive sul database, e farlo
    // mentre l'albero dei widget si sta costruendo e' il modo classico di
    // ritrovarsi un errore che non c'entra niente con la causa.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repository = ref.read(notificationsRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      if (repository != null && userId != null) {
        repository.markSeen(userId);
      }
    });
  }

  /// Apre sulla sezione dove c'e' qualcosa di nuovo.
  ///
  /// **E' la risposta alla domanda che ci si fa toccando la campanella**: non
  /// "quante notifiche ho" — quello lo dice gia' il pallino — ma *dove sono*.
  /// Atterrando sempre su VITTORIE, chi aveva due commenti nuovi trovava una
  /// schermata vuota e doveva cercarli sezione per sezione.
  ///
  /// Una volta sola, e prima che qualcuno tocchi: da li' in poi comanda chi
  /// guarda, e una schermata che si sposta sotto il dito e' peggio di una
  /// schermata che parte dal posto sbagliato.
  void _scegliLaSezione(List<AppNotification> notifiche, DateTime? seenAt) {
    if (_sezioneScelta || notifiche.isEmpty) {
      return;
    }

    _sezioneScelta = true;

    final conNovita = [
      for (final gruppo in NotificationGroup.values)
        if (notifiche.any(
          (riga) => riga.group == gruppo && riga.isUnreadSince(seenAt),
        ))
          gruppo,
    ];

    if (conNovita.isEmpty) {
      return;
    }

    final prima = conNovita.first;

    // Dopo la frame: cambiare lo stato di un provider mentre l'albero si sta
    // costruendo e' il modo classico di prendersi un errore che non nomina la
    // causa.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationFilterProvider.notifier).state = prima;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final letteFinoA = ref.watch(notificationsSeenAtProvider);

    if (!_congelato && letteFinoA.hasValue) {
      _congelato = true;
      _apertoCon = letteFinoA.value;
    }

    final seenAt = _congelato ? _apertoCon : letteFinoA.valueOrNull;

    _scegliLaSezione(notifications, seenAt);

    final filtro = ref.watch(notificationFilterProvider);
    final visibili = [
      for (final riga in notifications)
        if (riga.group == filtro) riga,
    ];

    // **Le vecchie non stanno in mezzo, stanno in fondo.** Sopra la settimana
    // una notizia non e' piu' una notizia: chi apre la campanella cerca cosa e'
    // successo adesso, e ritrovarsi venti righe di un mese fa in mezzo e' il
    // motivo per cui questa schermata sembrava un macello.
    final soglia = DateTime.now().subtract(_oldAfter);
    final recenti = [
      for (final riga in visibili)
        if (riga.createdAt == null || !riga.createdAt!.isBefore(soglia)) riga,
    ];
    final vecchie = [
      for (final riga in visibili)
        if (riga.createdAt != null && riga.createdAt!.isBefore(soglia)) riga,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche')),
      body: AppBackground(
        child: notifications.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: EmptyState(
                  title: 'Non ci sono notifiche',
                  message:
                      'Qui finisce quello che fanno gli altri: chi partecipa '
                      'alle tue missioni, chi accende una fiamma sulle tue '
                      'foto, chi commenta e chi ti nomina.',
                ),
              )
            : Column(
                children: [
                  _Filters(notifications: notifications, seenAt: seenAt),
                  Expanded(
                    child: visibili.isEmpty
                        ? const _NothingHere()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              // Meno margine del solito, e non e' una dimenticanza:
                              // il velo rosso delle righe non lette ha bisogno di
                              // respiro attorno, e alla pagina piena resterebbe
                              // stretto.
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            itemCount:
                                recenti.length + (vecchie.isEmpty ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (index < recenti.length) {
                                return _Row(notification: recenti[index]);
                              }

                              return _Older(notifications: vecchie);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Cosa si sta guardando nella campanella.
///
/// **Due sole, e una e' sempre scelta.** Il "tutto" di prima rimetteva insieme
/// quello che le sezioni erano state fatte per separare, e le richieste di
/// amicizia sono sparite del tutto: hanno gia' la loro scheda, con i comandi
/// per accettare o rifiutare, e tenerne due elenchi vuol dire doverli tenere
/// d'accordo.
final notificationFilterProvider = StateProvider.autoDispose<NotificationGroup>(
  (ref) => NotificationGroup.wins,
);

/// Le due parole in cima.
///
/// **Il rosso dice due cose diverse, e non si accavallano**: il colore della
/// parola dice quale sezione si sta guardando, il numero accanto dice quante
/// notizie nuove ci sono la' dentro. Le gia' lette non si contano — un numero
/// che non cala mai smette di voler dire qualcosa dopo due giorni.
class _Filters extends ConsumerWidget {
  const _Filters({required this.notifications, required this.seenAt});

  final List<AppNotification> notifications;
  final DateTime? seenAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(notificationFilterProvider);
    final palette = context.palette;
    final texts = context.texts;

    int nuove(NotificationGroup group) {
      return notifications
          .where((riga) => riga.group == group && riga.isUnreadSince(seenAt))
          .length;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      // **Scorre di lato.** Quattro parole, e una si chiama PARTECIPAZIONI: su
      // un telefono stretto l'ultima finirebbe fuori dallo schermo, e un filtro
      // che non si vede non lo usa nessuno.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final group in NotificationGroup.values)
              GestureDetector(
                onTap: () =>
                    ref.read(notificationFilterProvider.notifier).state = group,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Row(
                    children: [
                      Text(
                        group.label,
                        style: texts.labelSmall?.copyWith(
                          color: group == selected
                              ? palette.accent
                              : palette.textFaint,
                        ),
                      ),
                      if (nuove(group) > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${nuove(group)}',
                            style: texts.labelSmall?.copyWith(
                              color: palette.onAccent,
                              fontSize: 9,
                              height: 1.3,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Da quanto una notizia smette di essere una notizia.
const _oldAfter = Duration(days: 7);

/// Le vecchie, chiuse in una riga sola.
///
/// **Ci sono ma non ingombrano.** Aprirle e' un tocco, e chi lo fa sta cercando
/// una cosa precisa: nessuno scorre la campanella per rileggersi le fiamme del
/// mese scorso.
class _Older extends StatefulWidget {
  const _Older({required this.notifications});

  final List<AppNotification> notifications;

  @override
  State<_Older> createState() => _OlderState();
}

class _OlderState extends State<_Older> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  'PIU\' VECCHIE · ${widget.notifications.length}',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.textFaint,
                  ),
                ),
                const Spacer(),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: palette.textFaint,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          for (final notification in widget.notifications)
            _Row(notification: notification),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.notification});

  final AppNotification notification;

  void _open(BuildContext context) {
    if (notification.kind == NotificationKind.friendRequest) {
      context.push(AppRoutes.friends);

      return;
    }

    if (notification.challengeId.isNotEmpty) {
      context.push(AppRoutes.challengeDetailOf(notification.challengeId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final seenAt = ref.watch(notificationsSeenAtProvider).valueOrNull;
    final unread = notification.isUnreadSince(seenAt);
    final createdAt = notification.createdAt;
    final isWin = notification.kind == NotificationKind.win;

    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          // Un velo, non una scheda: niente bordo, niente ombra. Dice "questa
          // non l'hai ancora vista" e sparisce da solo alla visita dopo.
          color: unread ? palette.accentTint : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            _Face(notification: notification),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Message(notification: notification),
                  const SizedBox(height: 3),
                  // Seconda riga di servizio: **dove** e **quando**, piccoli e
                  // chiari. Prima l'ora stava in fondo alla riga e si portava
                  // via la larghezza del titolo della gara; qui non toglie
                  // niente a nessuno.
                  Row(
                    children: [
                      if (notification.challengeTitle.isNotEmpty)
                        Flexible(
                          child: Text(
                            notification.challengeTitle.toUpperCase(),
                            style: texts.labelSmall?.copyWith(
                              color: isWin ? palette.accent : palette.textFaint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (notification.challengeTitle.isNotEmpty &&
                          createdAt != null)
                        Text(
                          '  ·  ',
                          style: texts.labelSmall?.copyWith(
                            color: palette.textFaint,
                          ),
                        ),
                      if (createdAt != null)
                        Text(
                          AppDateUtils.shortTimeAgo(createdAt),
                          style: texts.labelSmall?.copyWith(
                            color: palette.textFaint,
                            letterSpacing: 0.4,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _Thumb(notification: notification),
            // Il pallino sta a destra e non a sinistra: a sinistra sposterebbe
            // il testo di ogni riga non letta, e l'elenco non sarebbe piu'
            // allineato con se stesso.
            if (unread) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cosa e' successo, scritto per essere letto di sfuggita.
///
/// Il nome di chi l'ha fatto sta in **grassetto** e il resto della frase no:
/// chi scorre cerca la persona, e trovarla senza leggere tutta la riga e' la
/// differenza fra un elenco che si guarda e uno che si legge.
class _Message extends StatelessWidget {
  const _Message({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final message = notification.message;

    // La vittoria e' l'unica riga che urla, e ha diritto di farlo: e' l'unica
    // che porta dei soldi.
    if (notification.kind == NotificationKind.win) {
      return Text(
        message.toUpperCase(),
        style: texts.titleLarge?.copyWith(
          color: palette.accent,
          letterSpacing: 0.6,
        ),
      );
    }

    final handle = '@${notification.actorUsername}';

    if (notification.actorUsername.isEmpty || !message.startsWith(handle)) {
      return Text(message, style: texts.bodyLarge, maxLines: 2);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: handle,
            style: texts.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          TextSpan(
            text: message.substring(handle.length),
            style: texts.bodyLarge?.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// La faccia di chi ha fatto la cosa, con sopra il segno di che cosa e'.
///
/// Il tondino in basso a destra vale piu' di quanto costa: dice fiamma, coppa,
/// fotocamera o amicizia **prima** che uno legga la frase, e su una campanella
/// piena e' l'unica cosa che rende l'elenco scorribile.
class _Face extends StatelessWidget {
  const _Face({required this.notification});

  static const double _size = 48;
  static const double _mark = 22;

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final kind = notification.kind;

    // La vittoria non la provoca nessuno: al posto della faccia c'e' la coppa,
    // e il tondino sarebbe la stessa cosa detta due volte.
    if (kind == NotificationKind.win) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: palette.accentTint,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.emoji_events, size: 26, color: palette.accent),
      );
    }

    final (icon, color) = switch (kind) {
      NotificationKind.fire => (Icons.local_fire_department, palette.accent),
      NotificationKind.participation => (
        Icons.photo_camera_rounded,
        palette.textPrimary,
      ),
      NotificationKind.friendRequest => (
        Icons.person_add_alt_1_rounded,
        palette.textPrimary,
      ),
      NotificationKind.win => (Icons.emoji_events, palette.accent),
      // La chiocciola: qualcuno ti ha chiamato per nome dentro un commento.
      NotificationKind.mention => (
        Icons.alternate_email_rounded,
        palette.textPrimary,
      ),
      // La sirena: la gara e' chiusa, i conti sono fatti.
      NotificationKind.ended => (Icons.flag_rounded, palette.textPrimary),
      NotificationKind.comment => (
        Icons.mode_comment_outlined,
        palette.textPrimary,
      ),
      // Le due degli amici: una gara lanciata e una foto mandata. Grigie, non
      // rosse: sono cose che riguardano gli altri, e il rosso qui dentro e'
      // riservato a quello che riguarda te.
      NotificationKind.friendChallenge => (
        Icons.add_circle_outline_rounded,
        palette.textPrimary,
      ),
      NotificationKind.friendEntry => (
        Icons.people_outline_rounded,
        palette.textPrimary,
      ),
    };

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FriendAvatar(
            userId: notification.actorId,
            username: notification.actorUsername,
            size: _size,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: _mark,
              height: _mark,
              // Il tondo del colore della pagina ritaglia un buco nella foto:
              // e' cio' che tiene l'icona leggibile su una faccia qualunque,
              // senza doverle mettere un bordo attorno.
              decoration: BoxDecoration(
                color: palette.background,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// La foto di cui parla la riga.
///
/// **E' quello che riempie la campanella**, e non e' decorazione: una riga che
/// dice "qualcuno ha dato una fiamma alla tua foto" senza far vedere *quale*
/// foto costringe ad aprirla per sapere di cosa si sta parlando. Con la foto
/// accanto, la riga si capisce da ferma.
///
/// Da dove si prende cambia con la notizia, e ogni volta e' roba gia' in casa:
///
/// - **fiamma** e **vittoria** parlano di una foto mia, e le mie partecipazioni
///   le legge gia' il profilo;
/// - **partecipazione** parla della foto che ha appena mandato un altro dentro
///   una gara mia, e quella sta nella gara.
///
/// Per una richiesta di amicizia non c'e' nessuna foto da mostrare: c'e' gia'
/// la faccia di chi l'ha mandata, ed e' esattamente il punto della notizia.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.notification});

  static const double _size = 52;

  final AppNotification notification;

  ChallengeEntry? _entry(WidgetRef ref) {
    final challengeId = notification.challengeId;

    if (challengeId.isEmpty) {
      return null;
    }

    if (notification.kind == NotificationKind.participation) {
      final entries =
          ref.watch(challengeEntriesProvider(challengeId)).valueOrNull ??
          const <ChallengeEntry>[];

      for (final entry in entries) {
        if (entry.userId == notification.actorId) {
          return entry;
        }
      }

      return null;
    }

    if (notification.kind == NotificationKind.friendRequest) {
      return null;
    }

    final mine = ref.watch(myEntriesProvider).valueOrNull ?? const [];

    for (final entry in mine) {
      if (entry.challengeId == challengeId) {
        return entry;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = _entry(ref);

    if (entry == null || entry.mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: SizedBox(
          width: _size,
          height: _size,
          // Un video non si apre qui dentro: venti righe che si mettono a
          // suonare mentre si scorre la campanella sono venti file scaricati
          // per un quadrato di due centimetri. Resta il segno che c'e' un
          // video, e per vederlo si apre la gara.
          child: entry.isVideo
              ? ColoredBox(
                  color: palette.surfaceMuted,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 22,
                    color: palette.textSecondary,
                  ),
                )
              : Image.network(
                  entry.previewUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      ColoredBox(color: palette.surfaceMuted),
                ),
        ),
      ),
    );
  }
}

/// La sezione scelta e' vuota, ma le altre no.
///
/// **Non e' lo stesso vuoto della campanella senza niente dentro**, e va detto
/// in modo diverso: li' non e' ancora successo niente, qui non e' successo
/// niente **di questo tipo** — e la differenza e' che basta toccare una parola
/// accanto per trovare qualcosa.
class _NothingHere extends ConsumerWidget {
  const _NothingHere();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final scelta = ref.watch(notificationFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Niente in '),
                TextSpan(
                  text: scelta.label,
                  style: TextStyle(color: palette.accent),
                ),
              ],
            ),
            style: context.texts.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Guarda nelle altre sezioni qui sopra.',
            style: context.texts.bodySmall?.copyWith(color: palette.textFaint),
          ),
        ],
      ),
    );
  }
}
