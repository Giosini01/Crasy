import 'dart:async';

import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tiene le schermate aggiornate senza che nessuno debba tirare giu' col dito.
///
/// Va detto cosa non e': Firestore **e' gia' in ascolto**, e una challenge
/// creata da un'altra persona compare da sola. Il problema che questo risolve e'
/// un altro e piu' insidioso: **le query hanno una data dentro**. "Le challenge
/// aperte" e' `endsAt > adesso`, dove *adesso* e' l'istante in cui la query e'
/// stata scritta. Restando fermi sulla stessa schermata, quell'istante invecchia:
/// una gara scaduta continua a comparire, una che comincia dopo non compare mai,
/// e il tempo che manca resta quello di quando si e' aperta l'app.
///
/// Ogni minuto le liste si rifanno con la data di adesso.
///
/// **Erano cinque secondi, e quel numero costava piu' di tutto il resto
/// dell'app messo insieme.** Il ragionamento scritto qui sotto — Firestore
/// serve dalla copia locale e va in rete solo per cio' che e' cambiato — e'
/// giusto per cinque provider su sette, e falso proprio per i due che pesano:
/// le due liste delle challenge portano `Timestamp.now()` **dentro la query**,
/// quindi a ogni giro la domanda era letteralmente un'altra, l'ascolto non
/// poteva riprendere da dove era e i documenti si rileggevano **tutti**. A
/// dodici giri al minuto erano settecentoventi riletture complete all'ora, per
/// ogni persona con l'app aperta.
///
/// Adesso quelle due query arrotondano l'orologio al minuto (vedi
/// `_adessoAlMinuto` in `FirestoreChallengeRepository`), quindi la domanda
/// resta la stessa per sessanta secondi e l'ascolto riprende invece di
/// ricominciare. Le due cose vanno insieme: il minuto qui e il minuto li'.
/// Cambiarne una sola rimette il problema, in piccolo.
///
/// Si rifanno **anche al ritorno dell'app**. E' il momento in cui il divario e'
/// piu' grande — il telefono e' rimasto in tasca un'ora — ed e' anche l'unico in
/// cui, su iPhone, i timer possono essere stati messi in pausa dal sistema.
class AutoRefresh extends ConsumerStatefulWidget {
  const AutoRefresh({required this.child, super.key});

  final Widget child;

  /// Ogni quanto.
  ///
  /// **Un minuto**, ed e' lo stesso minuto a cui sono arrotondate le due query
  /// delle challenge: rifarle piu' spesso non cambierebbe niente — la domanda
  /// sarebbe identica e tornerebbe la stessa risposta — e rifarle piu' di rado
  /// lascerebbe una gara scaduta in elenco piu' a lungo.
  ///
  /// Una gara che scade puo' restare in elenco fino a un minuto, e in quel
  /// minuto non sembra aperta: il tempo che manca lo conta `CountdownText`, che
  /// va per conto suo un secondo alla volta e scrive *chiusa* appena scade.
  static const Duration every = Duration(minutes: 1);

  @override
  ConsumerState<AutoRefresh> createState() => _AutoRefreshState();
}

class _AutoRefreshState extends ConsumerState<AutoRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(AutoRefresh.every, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();

      // **La seconda occasione per le notifiche.**
      //
      // Al primissimo avvio dopo l'installazione, su iPhone, Apple ci mette un
      // po' a consegnare il proprio recapito: se non fa in tempo, il telefono
      // resterebbe fuori dal registro fino alla disinstallazione. Riaprire
      // l'app e' il momento in cui quasi sempre ha gia' risposto, e non costa
      // niente riprovare: se il recapito e' gia' stato consegnato, questa
      // chiamata non fa nulla.
      final registro = ref.read(pushRegistryProvider);

      if (registro != null) {
        unawaited(registro.retryIfNeeded());

        // **E si segna il passaggio anche riaprendo, non solo avviando.**
        //
        // `lastSeenAt` serviva a una cosa sola — non mandare un richiamo a chi
        // e' passato ieri — e per quella bastava scriverlo all'avvio. Adesso
        // serve anche a dire quanta gente c'e' adesso, e all'avvio soltanto
        // non lo direbbe: chi tiene l'app aperta mezz'ora risulterebbe visto
        // mezz'ora fa, e chi la riapre venti volte al giorno una volta sola.
        //
        // E' una scrittura per riapertura, ed e' il prezzo giusto: senza, il
        // numero degli attivi sarebbe un numero inventato.
        final io = ref.read(currentUserIdProvider);

        if (io != null && io.isNotEmpty) {
          unawaited(registro.segnaPassaggio(io));
        }
      }
    }
  }

  /// Rifa' le liste che dipendono dall'orologio.
  ///
  /// Non tutte: i profili, il portafoglio e le notifiche non hanno una data
  /// dentro la query e restano in ascolto da soli. Invalidare anche quelli
  /// vorrebbe dire rifare delle letture per ottenere gli stessi dati.
  void _refresh() {
    if (!mounted) {
      return;
    }

    ref
      ..invalidate(liveChallengesProvider)
      ..invalidate(endedChallengesProvider)
      ..invalidate(myEntriesProvider)
      ..invalidate(myFriendsProvider)
      ..invalidate(incomingRequestsProvider)
      // Riaggancia sia elenco sia watermark al ritorno in primo piano: il
      // badge della Home non deve restare su una copia sospesa mentre l'app
      // era in background.
      ..invalidate(storedNotificationsProvider)
      ..invalidate(notificationsSeenAtProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
