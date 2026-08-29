import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Quanto aspetta un tocco singolo prima di valere, per non calpestare il
/// doppio tocco che potrebbe seguirlo.
///
/// Trecento millesimi e' la stessa attesa che usa Flutter per il doppio tocco,
/// ed e' misurata su come tocca la gente: a duecento, due tocchi fatti con
/// calma diventavano due tocchi singoli — cioe' la schermata che si apriva
/// invece della fiamma. Il prezzo e' che il tocco singolo parte un attimo dopo,
/// e su un gesto che apre una schermata non si nota.
const _doubleTapWindow = Duration(milliseconds: 300);

/// I gesti dell'ultima costruzione, per tipo di vista.
///
/// La fabbrica di un elemento si registra **una volta sola**, ma le funzioni da
/// chiamare cambiano a ogni ricostruzione: tenerle qui invece che dentro la
/// chiusura della fabbrica e' cio' che evita di ritrovarsi a chiamare il tocco
/// di una schermata che non c'e' piu'.
final _onTap = <String, VoidCallback?>{};
final _onDoubleTap = <String, VoidCallback?>{};

/// I video che il browser non ha lasciato partire, in attesa di un dito.
///
/// **Un solo tocco, ovunque nella pagina, li sblocca tutti.** Dopo la prima
/// interazione il browser considera la pagina "voluta" da chi la guarda e non
/// rifiuta piu' niente: e' la scorciatoia che rende i video di CRASY come
/// quelli delle app che partono da sole, anche dove le regole sono severe.
final _waitingForGesture = <web.HTMLVideoElement>{};
bool _listeningForGesture = false;

void _retryOnFirstGesture(web.HTMLVideoElement element) {
  _waitingForGesture.add(element);

  if (_listeningForGesture) {
    return;
  }

  _listeningForGesture = true;

  // L'ascolto resta acceso per sempre, ed e' voluto: i video che arrivano dopo
  // — scorrendo — possono trovare le stesse porte chiuse. Costa un ascoltatore
  // solo, e quando non c'e' niente in attesa non fa niente.
  web.document.addEventListener(
    'pointerdown',
    ((web.Event _) {
      for (final video in _waitingForGesture.toList()) {
        video.play().toDart.then<void>((_) {}, onError: (Object _) {});
      }

      _waitingForGesture.clear();
    }).toJS,
  );
}

/// Prova a partire con l'audio, e se il browser dice di no riparte muto.
///
/// Meglio un video che va senza suono che un video fermo: il pulsante del
/// volume resta li' per chi lo vuole.
void _playAloud(web.HTMLVideoElement element) {
  element.muted = false;
  element.play().toDart.then<void>(
    (_) {},
    onError: (Object _) {
      element.muted = true;
      element.play().toDart.then<void>((_) {}, onError: (Object _) {});
    },
  );
}

/// Un video sul web, disegnato da un vero elemento `<video>` del browser.
///
/// **Non usa il lettore di Flutter, ed e' la correzione di un difetto che non
/// dava nessun segnale.** Quel lettore considera un video "pronto" quando il
/// browser dice di poterlo riprodurre; ma iPhone, per non consumare dati, **non
/// scarica niente** finche' qualcuno non tocca play. Quel momento non arrivava
/// mai, quindi il video non risultava ne' pronto ne' rotto: restava un
/// rettangolo grigio, per sempre, senza un errore da nessuna parte.
///
/// Qui l'elemento e' nostro, e ha **due mestieri**.
///
/// ## Nell'elenco: parte da solo, e non ha comandi
///
/// Un video che chiede di premere play prima di mostrarsi viene saltato: si
/// scorre una gara guardando venti contenuti di fila, e chi guarda non sa
/// nemmeno cosa sta rifiutando finche' non lo vede muoversi. Quindi parte da
/// solo, **muto e in ciclo**, e senza un comando sopra — una barra di pulsanti
/// in mezzo a una griglia di foto dice "questo e' un lettore" invece di "questa
/// e' la partecipazione di qualcuno".
///
/// L'attributo `autoplay` da solo non basta ovunque, quindi la partenza si
/// chiede anche a voce con `play()`. **Il rifiuto e' un caso previsto**: dove
/// non si puo' partire senza un dito compaiono i comandi del sistema, con il
/// loro play in mezzo allo schermo.
///
/// ## A schermo intero: audio, e il tocco per fermare
///
/// Un tocco apre la partecipazione a schermo intero, e li' [immersive] e' vero:
/// il video diventa una cosa che si guarda, con l'audio acceso.
///
/// **I comandi del browser restano spenti anche li'**, e con loro la barra per
/// andare avanti e indietro. Una partecipazione dura pochi secondi e va
/// guardata come e' stata girata: potendo saltare si salta al punto in cui
/// succede la cosa, e chi l'ha girata ha lavorato anche sui secondi prima. Non
/// esiste un modo di tenere la barra togliendo solo il salto, quindi si toglie
/// tutto — a fermare e riprendere ci pensa il tocco.
///
/// ## Un tocco e due tocchi
///
/// Sopra un elemento del browser i gesti di Flutter non arrivano: il `<video>`
/// se li prende tutti, e finche' se li teneva **sui video non si poteva dare la
/// fiamma**. Qui i due gesti si riconoscono nel browser e si rimandano a chi di
/// dovere: un tocco apre, due tocchi accendono la fiamma come su qualunque
/// foto. Il tocco singolo aspetta un attimo prima di valere — senza
/// quell'attimo un doppio tocco aprirebbe anche lo schermo intero.
///
/// ## Suona solo quello che si sta guardando
///
/// Venti video in una pagina che partono tutti insieme sono venti file che
/// scendono insieme, e su un telefono e' la differenza fra un'app e un conto
/// del traffico. Un `IntersectionObserver` tiene acceso **solo cio' che sta
/// davvero sullo schermo**: quello che esce si ferma, quello che entra riparte.
/// Con `preload = 'metadata'` chi e' fuori dallo schermo non scarica altro che
/// il primo fotogramma e le proporzioni — abbastanza per non lasciare un buco
/// grigio mentre si scorre.
Widget? buildHtmlVideo(
  String url, {
  bool immersive = false,
  VoidCallback? onTap,
  VoidCallback? onDoubleTap,
}) {
  // Il nome della fabbrica porta dentro l'indirizzo e il mestiere: lo stesso
  // video nell'elenco e a schermo intero sono due elementi diversi, e lo stesso
  // video riaperto riusa la sua fabbrica invece di registrarne una nuova a ogni
  // ricostruzione.
  final viewType = 'crasy-video-${immersive ? 'full' : 'feed'}-${url.hashCode}';

  _onTap[viewType] = onTap;
  _onDoubleTap[viewType] = onDoubleTap;

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final element = web.document.createElement('video') as web.HTMLVideoElement;

    // **Gli attributi prima dell'indirizzo, e non e' pignoleria.**
    //
    // iPhone decide se un video ha il diritto di partire da solo **guardando
    // gli attributi che ha addosso quando comincia a caricarsi**. Scritti come
    // proprieta' dopo `src` — cioe' come veniva naturale — arrivano troppo
    // tardi: il video risulta "con l'audio" per un istante, il permesso viene
    // negato li', e non lo si riottiene mettendo `muted` un attimo dopo.
    //
    // E' il motivo per cui i video si vedevano ma restavano fermi.
    if (!immersive) {
      element.setAttribute('muted', '');
    }

    element
      ..setAttribute('playsinline', '')
      // **Niente menu a tendina del browser.** Tenendo il dito su un video —
      // o con il tasto destro — Chrome apre il suo menu: pausa, schermo
      // intero, *scarica*, velocita' di riproduzione. Dentro CRASY non ha
      // senso nemmeno una di quelle voci, e "scarica" su una foto in gara e'
      // proprio la cosa che non deve esserci. Il dito tenuto premuto su una
      // partecipazione non deve far comparire niente.
      ..setAttribute(
        'controlsList',
        'nodownload noplaybackrate noremoteplayback',
      )
      ..setAttribute('disablepictureinpicture', '')
      // Il vecchio nome dello stesso attributo. Le versioni di iOS che stanno
      // ancora in giro conoscono solo quello, e senza aprono il video a tutto
      // schermo al primo play invece di lasciarlo nella pagina.
      ..setAttribute('webkit-playsinline', '')
      ..setAttribute('autoplay', '')
      ..autoplay = true
      ..loop = true
      ..playsInline = true
      // **Niente comandi del browser, nemmeno a schermo intero.**
      //
      // La barra nativa porta con se' il trascinamento, e su una
      // partecipazione andare avanti non si deve: dura pochi secondi e va
      // guardata come e' stata girata. Non esiste un modo di tenere la barra
      // togliendo solo il salto — `controlsList` sa dire "niente scarica" e
      // "niente velocita'", non "niente scorrimento" — quindi si toglie tutto,
      // e a fermare e riprendere ci pensa il tocco.
      ..controls = false
      ..muted = !immersive
      ..preload = 'metadata'
      // Per ultimo: da qui parte il caricamento, e da qui in poi cambiare le
      // regole non serve piu' a niente.
      ..src = url;

    // Il menu contestuale si nega qui, e vale anche dove i comandi ci sono: a
    // schermo intero non serve nessuna delle voci di quel menu.
    element.oncontextmenu = ((web.Event event) {
      event.preventDefault();

      return false.toJS;
    }).toJS;

    element.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = immersive ? 'contain' : 'cover'
      ..backgroundColor = 'transparent';

    if (immersive) {
      _playAloud(element);

      return element;
    }

    void start() {
      // Adesso questo video si sta guardando davvero: puo' scaricare quanto gli
      // serve. Finche' era fuori dallo schermo ha preso solo il primo
      // fotogramma, ed e' li' che si risparmia il traffico.
      element.preload = 'auto';

      element.play().toDart.then<void>(
        (_) {},
        // **Non e' un errore, e' una regola del browser**: senza un dito non si
        // parte. Prima quel rifiuto lasciava un fotogramma fermo senza niente
        // sopra, e sembrava un video rotto; adesso mette in mano i comandi — e
        // si rimane in attesa del primo tocco, ovunque sia, per riprovare.
        // **Nell'elenco non compare nessuna barra di comandi.** Prima, quando
        // il browser rifiutava la partenza, si ripiegava sui comandi nativi: su
        // una miniatura larga due centimetri diventava una fascia grigia che
        // copriva meta' della foto, e chi la vedeva pensava che l'app fosse
        // rotta. Meglio il primo fotogramma fermo e il tocco che lo sblocca.
        onError: (Object _) => _retryOnFirstGesture(element),
      );
    }

    // I dati arrivano dopo, e il primo `play()` puo' essere partito quando non
    // c'era ancora niente da mostrare: quando ce n'e' abbastanza si riprova.
    // Nell'elenco un video fermo non lo ha fermato nessuno — li' non ci sono
    // comandi da toccare — quindi fermo vuol dire soltanto "non e' partito".
    element.addEventListener(
      'loadeddata',
      ((web.Event _) {
        if (element.paused) {
          start();
        }
      }).toJS,
    );

    // **Il doppio tocco lo conta questo codice, non il browser.**
    //
    // Prima ci si affidava all'evento `dblclick`, ed e' li' che si rompeva: sul
    // telefono quell'evento non arriva sempre: quando manca restano due `click`
    // normali, il secondo fa scadere l'attesa del primo, e invece della fiamma
    // si apriva il video — a volte due volte di fila.
    //
    // Contando i tocchi qui, il caso non esiste: se ne arriva un secondo mentre
    // il primo sta ancora aspettando, **quello e' un doppio tocco**, e il
    // singolo non parte piu'. Non c'e' nessun evento del browser da sperare che
    // arrivi.
    Timer? pending;

    element.onclick = ((web.Event _) {
      if (pending != null) {
        pending!.cancel();
        pending = null;
        _onDoubleTap[viewType]?.call();

        return;
      }

      pending = Timer(_doubleTapWindow, () {
        pending = null;
        _onTap[viewType]?.call();
      });
    }).toJS;

    // Resta solo per impedire quello che il browser farebbe da solo con due
    // tocchi rapidi — selezionare, ingrandire. Il gesto se l'e' gia' preso il
    // conteggio qui sopra.
    element.ondblclick = ((web.Event event) {
      event.preventDefault();
    }).toJS;

    web.IntersectionObserver(
      ((
            JSArray<web.IntersectionObserverEntry> entries,
            web.IntersectionObserver _,
          ) {
            for (final entry in entries.toDart) {
              if (entry.isIntersecting) {
                start();
              } else {
                element.pause();
              }
            }
          })
          .toJS,
      // Meta' riquadro: un video che spunta dal bordo lo si sta arrivando a
      // guardare, uno che ne mostra un angolo no.
      web.IntersectionObserverInit(threshold: 0.5.toJS),
    ).observe(element);

    start();

    return element;
  });

  return HtmlElementView(viewType: viewType);
}
