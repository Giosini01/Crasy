import 'dart:async';

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/icon_badge.dart';
import 'package:crasy/features/notifications/data/push_registry.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsRepositoryProvider =
    Provider<FirestoreNotificationsRepository?>((ref) {
      if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
        return null;
      }

      return FirestoreNotificationsRepository(
        ref.watch(firebaseFirestoreProvider),
      );
    });

/// Le notifiche scritte da altri: partecipazioni e fiamme.
final storedNotificationsProvider = StreamProvider<List<AppNotification>>((
  ref,
) {
  final repository = ref.watch(notificationsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const <AppNotification>[]);
  }

  return repository.watch(userId);
});

/// Quando si e' aperta la campanella l'ultima volta.
final notificationsSeenAtProvider = StreamProvider<DateTime?>((ref) {
  final repository = ref.watch(notificationsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(null);
  }

  return repository.watchSeenAt(userId);
});

/// Tutte le notifiche, quelle scritte e quelle ricavate, in un elenco solo.
///
/// Le vittorie e gli avvisi sulla scelta **non stanno sul database come
/// notifiche**: si ricavano da dati che esistono gia'. Scriverle sarebbe fare
/// una copia di qualcosa che puo' cambiare — una richiesta ritirata lascerebbe
/// in campanella l'avviso di una richiesta che non c'e' piu', e togliere quella
/// riga vorrebbe dire tenere sincronizzate due verita' invece di leggerne una.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final stored = ref.watch(storedNotificationsProvider).valueOrNull ?? const [];
  final myEntries = ref.watch(myEntriesProvider).valueOrNull ?? const [];
  final ended = ref.watch(endedChallengesProvider).valueOrNull ?? const [];
  final viste = ref.watch(revealsSeenProvider).valueOrNull ?? const <String>{};

  // Le gare finite che non hanno ancora un vincitore proclamato: dura un
  // istante, perche' la chiude il primo che le apre.
  final aspettano = [
    for (final challenge in ended)
      if (challenge.winnerEntryId == null) challenge,
  ];
  final partecipate = {for (final entry in myEntries) entry.challengeId};

  final all = <AppNotification>[
    ...stored,
    // **Chi ha partecipato sa che la gara e' chiusa.**
    //
    // Una gara che finisce e poi tace e' il modo piu' rapido di far pensare che
    // i soldi non arriveranno. Qui si dice che e' finita, e chi ha mandato una
    // foto va a vedere com'e' andata — che e' anche il momento in cui una
    // vittoria si scopre senza aspettare che qualcuno la comunichi.
    for (final challenge in aspettano)
      if (partecipate.contains(challenge.id))
        AppNotification(
          id: 'finita_${challenge.id}',
          kind: NotificationKind.ended,
          challengeId: challenge.id,
          challengeTitle: challenge.title,
          createdAt: challenge.endsAt,
        ),
    // **La vittoria compare solo dopo il rullo di tamburi.**
    //
    // Questa riga si ricava dalla partecipazione, quindi esisterebbe
    // dall'istante della proclamazione: chi tocca la notifica *e' finita* e
    // passa di qui leggerebbe il finale in campanella, e il rullo arriverebbe
    // dopo a raccontare una cosa gia' saputa. Aspetta il suo turno.
    for (final entry in myEntries)
      if (entry.isWinner && viste.contains(entry.challengeId))
        AppNotification(
          id: 'vittoria_${entry.challengeId}',
          kind: NotificationKind.win,
          challengeId: entry.challengeId,
          challengeTitle: entry.challengeTitle,
          createdAt: entry.createdAt,
        ),
  ];

  all.sort((a, b) {
    final at = a.createdAt;
    final bt = b.createdAt;

    if (at == null && bt == null) {
      return 0;
    }

    if (at == null) {
      return -1;
    }

    if (bt == null) {
      return 1;
    }

    return bt.compareTo(at);
  });

  return all;
});

/// Quante notifiche sono arrivate dall'ultima occhiata.
///
/// E' il numero rosso sulla campanella, e si ferma a nove: oltre, il numero
/// preciso non aiuta a decidere niente e un pallino largo mezza icona da'
/// fastidio.
final unreadNotificationsProvider = Provider<int>((ref) {
  final seenAt = ref.watch(notificationsSeenAtProvider).valueOrNull;

  return ref
      .watch(notificationsProvider)
      .where((notification) => notification.isUnreadSince(seenAt))
      .length;
});

/// Segna la casella come letta attraverso l'unica verita' gia' usata dalla
/// campanella. Il tap push lo chiama anche quando la destinazione non e' la
/// pagina delle notifiche (per esempio una challenge terminata).
Future<void> markNotificationsSeen(WidgetRef ref) async {
  final repository = ref.read(notificationsRepositoryProvider);
  final userId = ref.read(currentUserIdProvider);

  if (repository != null && userId != null) {
    await repository.markSeen(userId);
  }
}

/// Il registro dei dispositivi per le notifiche.
final pushRegistryProvider = Provider<PushRegistry?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return PushRegistry(
    ref.watch(firebaseFirestoreProvider),
    FirebaseMessaging.instance,
  );
});

/// Tiene il registro dei dispositivi allineato a chi e' collegato.
///
/// **Si accende e si spegne da solo**, seguendo la sessione: chi entra registra
/// il proprio telefono, chi esce lo toglie. Senza la seconda meta', il telefono
/// di chi ha fatto uscire l'account continuerebbe a ricevere le notifiche di
/// quella persona — anche mesi dopo, anche se nel frattempo lo usa qualcun
/// altro.
///
/// Il permesso si chiede qui e non all'avvio, ed e' una scelta che non si puo'
/// disfare: su iPhone la richiesta si fa **una volta sola** nella vita
/// dell'installazione. Chiederla prima che uno abbia capito cosa sia CRASY
/// vuol dire bruciarla.
final pushRegistrationProvider = Provider<void>((ref) {
  final registro = ref.watch(pushRegistryProvider);

  if (registro == null) {
    return;
  }

  // **Si guarda l'identificativo, non la sessione intera.**
  //
  // Guardando la sessione, questo provider si rifaceva a ogni respiro: Firebase
  // avvisa non solo quando si entra e si esce, ma anche a ogni rinnovo del
  // gettone, a ogni ricarica dei dati, quando si conferma l'email, quando si
  // aggancia il numero — tre o quattro volte nei primi secondi. E a ogni giro
  // il vecchio veniva smontato, il che cancellava l'indirizzo appena scritto.
  // **L'app si toglieva dal registro da sola**, e il registro restava vuoto
  // qualunque cosa si facesse.
  //
  // L'identificativo invece cambia solo quando cambia davvero la persona: si
  // entra, si esce, si passa a un altro account. Che e' esattamente quando
  // questo lavoro va rifatto.
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    // Nessuno collegato: si toglie il telefono dal registro di chi c'era prima,
    // altrimenti continuerebbe a ricevere le sue notifiche per mesi.
    unawaited(registro.forget());

    return;
  }

  unawaited(registro.register(userId));
});

/// Un tocco su una notifica arrivata sullo schermo bloccato.
///
/// **Sono due indirizzi e non uno, e la differenza e' tutta qui.** La
/// campanella non e' una scheda: e' una pagina che si **apre sopra** le schede,
/// e come tutte quelle ha una freccia per tornare indietro. Aprirla come se
/// fosse una scheda la lascia sola, senza niente sotto: la freccia non compare,
/// il gesto per tornare non ha dove andare, e chi ci arriva e' in trappola —
/// gli resta solo chiudere l'app.
///
/// Percio' un tocco dice due cose: su quale **scheda** appoggiarsi, e quale
/// **pagina** aprirci sopra. Per una missione nuova la seconda non serve: la
/// scheda delle gare e' essa stessa la destinazione.
///
/// **Il momento serve quanto la destinazione.** Senza, due tocchi di fila sullo
/// stesso tipo di notifica sarebbero lo stesso identico valore, e chi ascolta i
/// cambiamenti non vedrebbe cambiare niente: il secondo tocco non porterebbe da
/// nessuna parte.
typedef PushTap = ({
  String scheda,
  String? apri,
  String? evidenzia,
  String? notificationId,

  /// Se l'app era **chiusa** e l'ha aperta questa notifica.
  ///
  /// Cambia tutto su come ci si muove. Ad app chiusa non c'e' niente sotto:
  /// bisogna posare una scheda e poi appoggiarci sopra la pagina, o si finisce
  /// su qualcosa da cui non si torna indietro.
  ///
  /// Ad app aperta invece **sotto c'e' gia' quello che si stava guardando**:
  /// rimettere la scheda delle gare vuol dire strappare via una schermata e
  /// farne scivolare un'altra sopra — due movimenti per una cosa sola, ed e'
  /// quello che faceva sembrare tutto sconnesso.
  bool daFermo,
  int quando,
});

/// Dove portare chi tocca una notifica.
///
/// **Aprire l'app e basta e' un vicolo cieco.** Una notifica dice che e'
/// successo qualcosa; toccarla e ritrovarsi sulla schermata dove si era rimasti
/// l'altro ieri costringe a cercare da soli la cosa di cui parlava — e nove
/// volte su dieci non la si cerca.
///
/// Due strade sole, perche' due sono le specie di notizia. Una missione nuova o
/// la sfida del giorno riguardano **una gara**: si va dove stanno le gare. Una
/// fiamma, un commento, una nomina, una vittoria riguardano **te**: si va in
/// campanella, che e' il posto in cui c'e' scritto chi e' stato e sotto cosa.
///
/// Non si apre la singola gara nemmeno quando l'annuncio ne conosce
/// l'identificativo: l'annuncio non dice quale sia — di proposito — e portare
/// dritti dentro una gara che nessuno aveva nominato toglie il momento in cui
/// la si sceglie, che e' mezzo il gioco.
final pushTapsProvider = StreamProvider<PushTap>((ref) async* {
  // Sul web le notifiche non sono accese: non c'e' nessun tocco da ascoltare.
  if (kIsWeb || !ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return;
  }

  PushTap dove(RemoteMessage messaggio, {required bool daFermo}) {
    final kind = messaggio.data['kind'] ?? '';

    // Una missione nuova o la sfida del giorno riguardano **una gara**: si va
    // dove stanno le gare, e non c'e' niente da aprire sopra.
    if (kind == 'newChallenge' || kind == 'daily') {
      return (
        scheda: AppRoutes.challenges,
        apri: null,
        evidenzia: null,
        notificationId: null,
        daFermo: daFermo,
        quando: DateTime.now().microsecondsSinceEpoch,
      );
    }

    // **Una gara finita porta alla gara, non in campanella.**
    //
    // E' l'unica notifica che non racconta un fatto ma ne annuncia uno: dice
    // che il tempo e' scaduto e **non dice chi ha vinto**. Il finale sta nella
    // missione, dove si apre con il rullo di tamburi — portare chi tocca in
    // campanella vorrebbe dire fargli leggere "la missione e' finita" e poi
    // cercarsi da solo dove si guarda com'e' andata.
    if (kind == 'ended') {
      final gara = messaggio.data['challengeId'] ?? '';

      if (gara.isNotEmpty) {
        return (
          scheda: AppRoutes.challenges,
          apri: AppRoutes.challengeDetailOf(gara),
          evidenzia: null,
          notificationId: messaggio.data['notificationId'],
          daFermo: daFermo,
          quando: DateTime.now().microsecondsSinceEpoch,
        );
      }
    }

    // **Una richiesta di amicizia non finisce in campanella.** Non c'e' una
    // riga da accendere: c'e' una scheda con i tasti per accettare o rifiutare,
    // ed e' li' che serve arrivare. Portare in campanella chi ha toccato quella
    // notifica vorrebbe dire fargli cercare da solo dove si risponde.
    if (kind == 'friendRequest') {
      return (
        scheda: AppRoutes.profile,
        apri: AppRoutes.friends,
        evidenzia: null,
        notificationId: null,
        daFermo: daFermo,
        quando: DateTime.now().microsecondsSinceEpoch,
      );
    }

    // Tutto il resto — fiamme, commenti, nomine, vittorie — riguarda **te**: si
    // va in campanella, sulla riga precisa da cui si e' arrivati.
    return (
      scheda: AppRoutes.challenges,
      apri: AppRoutes.notifications,
      evidenzia: messaggio.data['notificationId'],
      notificationId: messaggio.data['notificationId'],
      daFermo: daFermo,
      quando: DateTime.now().microsecondsSinceEpoch,
    );
  }

  // **Chi arriva da un'app chiusa passa di qui.** Toccando una notifica con
  // CRASY spenta, l'app parte da zero e il tocco non lo racconta nessuno: resta
  // solo questo messaggio, che va chiesto una volta all'avvio. Senza, la
  // notifica funziona solo per chi aveva gia' l'app aperta in sottofondo —
  // cioe' quasi mai.
  // **Lo stesso messaggio non deve valere due volte.** Capita che il tocco
  // arrivi sia come "messaggio che ha aperto l'app" sia sul flusso di quelli
  // aperti: senza questo controllo si aprirebbero due campanelle, una sopra
  // l'altra, e la prima freccia indietro riporterebbe alla seconda. E' uno dei
  // modi in cui la faccenda sembrava sconnessa.
  final gia = <String>{};

  bool nuovo(RemoteMessage messaggio) {
    final id = messaggio.messageId;

    return id == null || gia.add(id);
  }

  final iniziale = await FirebaseMessaging.instance.getInitialMessage();

  if (iniziale != null && nuovo(iniziale)) {
    yield dove(iniziale, daFermo: true);
  }

  yield* FirebaseMessaging.onMessageOpenedApp
      .where(nuovo)
      .map((messaggio) => dove(messaggio, daFermo: false));
});

/// Tiene spento il numero rosso sull'icona.
///
/// **Chiude la meta' del difetto che il codice nativo non puo' vedere.** Quando
/// l'app torna in primo piano, ad azzerare il pallino ci pensa iOS insieme a
/// noi; ma una notifica che arriva **mentre l'app e' gia' aperta** non fa
/// tornare l'app da nessuna parte — c'e' gia' — e il numero comparirebbe sotto
/// gli occhi di chi sta guardando lo schermo per poi restare acceso all'uscita.
///
/// L'unico che sa che in quel momento e' arrivato qualcosa e' questo ascolto.
final pushBadgeProvider = Provider<void>((ref) {
  if (kIsWeb || !ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return;
  }

  const pallino = IconBadge();

  // All'avvio: chi apre l'app dalla schermata di casa senza toccare la
  // notifica passa da qui.
  unawaited(pallino.clear());

  final ascolto = FirebaseMessaging.onMessage.listen(
    (_) => unawaited(pallino.clear()),
  );

  ref.onDispose(ascolto.cancel);
});
