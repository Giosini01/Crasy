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
    for (final entry in myEntries)
      if (entry.isWinner)
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

  PushTap dove(RemoteMessage messaggio) {
    final kind = messaggio.data['kind'] ?? '';

    // Una missione nuova o la sfida del giorno riguardano **una gara**: si va
    // dove stanno le gare, e non c'e' niente da aprire sopra.
    if (kind == 'newChallenge' || kind == 'daily') {
      return (
        scheda: AppRoutes.challenges,
        apri: null,
        evidenzia: null,
        quando: DateTime.now().microsecondsSinceEpoch,
      );
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
        quando: DateTime.now().microsecondsSinceEpoch,
      );
    }

    // Tutto il resto — fiamme, commenti, nomine, vittorie — riguarda **te**: si
    // va in campanella, sulla riga precisa da cui si e' arrivati.
    return (
      scheda: AppRoutes.challenges,
      apri: AppRoutes.notifications,
      evidenzia: messaggio.data['notificationId'],
      quando: DateTime.now().microsecondsSinceEpoch,
    );
  }

  // **Chi arriva da un'app chiusa passa di qui.** Toccando una notifica con
  // CRASY spenta, l'app parte da zero e il tocco non lo racconta nessuno: resta
  // solo questo messaggio, che va chiesto una volta all'avvio. Senza, la
  // notifica funziona solo per chi aveva gia' l'app aperta in sottofondo —
  // cioe' quasi mai.
  final iniziale = await FirebaseMessaging.instance.getInitialMessage();

  if (iniziale != null) {
    yield dove(iniziale);
  }

  yield* FirebaseMessaging.onMessageOpenedApp.map(dove);
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
