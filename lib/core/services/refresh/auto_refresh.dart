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
/// Ogni cinque secondi le liste si rifanno con la data di adesso. Non e' un
/// costo che si sente: Firestore serve dalla copia locale quello che ha gia', e
/// va in rete solo per cio' che e' davvero cambiato.
///
/// Si rifanno **anche al ritorno dell'app**. E' il momento in cui il divario e'
/// piu' grande — il telefono e' rimasto in tasca un'ora — ed e' anche l'unico in
/// cui, su iPhone, i timer possono essere stati messi in pausa dal sistema.
class AutoRefresh extends ConsumerStatefulWidget {
  const AutoRefresh({required this.child, super.key});

  final Widget child;

  /// Ogni quanto. Cinque secondi e' quello che serve a non far mai vedere una
  /// gara scaduta come aperta, che e' la cosa che qui si sta evitando.
  static const Duration every = Duration(seconds: 5);

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
      ..invalidate(incomingRequestsProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
