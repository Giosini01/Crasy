import 'dart:async';

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/refresh/auto_refresh.dart';
import 'package:crasy/core/theme/app_theme.dart';
import 'package:crasy/core/widgets/opening_curtain.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrasyApp extends ConsumerStatefulWidget {
  const CrasyApp({super.key});

  @override
  ConsumerState<CrasyApp> createState() => _CrasyAppState();
}

class _CrasyAppState extends ConsumerState<CrasyApp> {
  /// Il tocco arrivato mentre la sessione non era ancora in piedi.
  ///
  /// **E' il pezzo che mancava, ed e' il motivo per cui toccare una notifica
  /// sembrava fare un casino.** Toccandola ad app chiusa, l'app parte e per
  /// qualche istante non sa ancora chi sei: in quel momento **ogni indirizzo
  /// viene dirottato** al muro che tocca passare — l'accesso, la conferma
  /// dell'email, i consensi. Il nostro salto partiva li' dentro e veniva
  /// sbattuto via insieme agli altri, quindi si finiva ogni volta in un posto
  /// diverso a seconda di quanto ci aveva messo la rete a rispondere.
  ///
  /// Adesso il tocco si mette da parte e si consuma **quando la sessione e'
  /// completa**, cioe' quando esiste davvero una schermata su cui atterrare.
  PushTap? _inAttesa;

  /// Va dove dice il tocco, dando per scontato che si possa.
  ///
  /// **Il router si chiede adesso, non si tiene da parte.** E' costruito sopra
  /// la sessione, quindi quando la sessione cambia ne nasce uno nuovo e quello
  /// di prima non comanda piu' niente: un salto fatto su quello vecchio non
  /// succede e basta, senza errori. E' esattamente il caso che conta qui, visto
  /// che questo tocco si consuma **proprio nell'istante in cui la sessione
  /// finisce di aprirsi** — l'ha trovato una prova, non un telefono.
  void _porta(PushTap dove) {
    final router = ref.read(goRouterProvider);

    // **Ad app chiusa si posa prima una scheda.** Sotto non c'e' niente, e
    // aprire una pagina sul vuoto vuol dire una schermata senza freccia da cui
    // si esce solo chiudendo l'app.
    //
    // Ad app aperta no: sotto c'e' gia' quello che si stava guardando, e
    // rimettere la scheda delle gare sarebbe strappare via una schermata per
    // farne scivolare un'altra sopra — due movimenti per una cosa sola.
    if (dove.daFermo) {
      router.go(dove.scheda);
    }

    if (dove.apri case final pagina?) {
      final quale = dove.evidenzia;
      final indirizzo = quale == null || quale.isEmpty
          ? pagina
          : '$pagina?evidenzia=${Uri.encodeComponent(quale)}';

      // **Non si apre due volte la stessa pagina.** Chi tocca due notifiche di
      // fila si ritroverebbe due campanelle impilate, e due frecce indietro per
      // uscire da quella che ha aperto una volta sola.
      if (router.state.matchedLocation == pagina) {
        router.replace(indirizzo);

        return;
      }

      router.push(indirizzo);
    }
  }

  /// Prende il tocco, e decide se e' il momento di usarlo.
  void _prendi(PushTap dove) {
    // Il tap e' gia' una lettura, anche se porta direttamente a una challenge
    // terminata invece che alla campanella. Aspettare solo `NotificationsPage`
    // lasciava il badge acceso per quel flusso.
    if (dove.notificationId case final id? when id.isNotEmpty) {
      unawaited(markNotificationsSeen(ref));
    }

    final adesso = ref.read(sessionLandingRouteProvider);

    if (!AppRoutes.tabs.contains(adesso)) {
      _inAttesa = dove;

      return;
    }

    _porta(dove);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    // **Il registro dei dispositivi si accende qui**, e non dentro una
    // schermata: deve seguire la sessione — chi entra registra il proprio
    // telefono, chi esce lo toglie — e nessuna schermata resta aperta per tutta
    // la sessione. Guardato da qui, vive quanto l'app.
    ref.watch(pushRegistrationProvider);

    // **E il numero rosso sull'icona non resta mai acceso a sproposito.** Vale
    // per le notifiche che arrivano ad app aperta: il ritorno in primo piano lo
    // vede il codice nativo, questo caso lo vede solo Dart.
    ref.watch(pushBadgeProvider);

    // **E qui si ascolta chi tocca una notifica.** Sta accanto al registro per
    // lo stesso motivo: il tocco puo' arrivare in qualunque momento — anche
    // nell'istante in cui l'app parte, se e' stata proprio la notifica ad
    // averla aperta — e non c'e' nessuna schermata che sia gia' in piedi quando
    // succede.
    ref.listen(pushTapsProvider, (_, tocco) {
      final dove = tocco.valueOrNull;

      if (dove != null) {
        _prendi(dove);
      }
    });

    // E quando la sessione finisce di aprirsi, il tocco messo da parte si
    // consuma. Senza questo, chi tocca una notifica ad app chiusa passa dai
    // muri d'ingresso e poi resta dove l'hanno lasciato i muri.
    ref.listen(sessionLandingRouteProvider, (_, arrivo) {
      final atteso = _inAttesa;

      if (atteso != null && AppRoutes.tabs.contains(arrivo)) {
        _inAttesa = null;

        // Dopo la frame: qui l'albero si sta ricostruendo per il cambio di
        // sessione, e muovere il router nel mezzo e' il modo classico di
        // prendersi un errore che non nomina la causa.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _porta(atteso);
          }
        });
      }
    });

    return MaterialApp.router(
      title: 'CRASY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Bloccata sul chiaro: l'app non segue il tema di sistema, cosi' le foto
      // cadono sempre sullo stesso fondo e il rosso ha sempre lo stesso peso.
      themeMode: ThemeMode.light,
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Le liste con una data dentro si rifanno da sole ogni pochi secondi.
      // Sta qui e non dentro una schermata perche' vale per tutte, e perche'
      // deve continuare a girare anche mentre si cambia scheda.
      builder: (context, child) => AutoRefresh(
        child: OpeningCurtain(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
