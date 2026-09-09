import 'package:crasy/core/constants/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Mandare una foto fuori da CRASY.
///
/// E' la porta d'ingresso dell'app, non un dettaglio di cortesia. Il giro e'
/// questo: uno partecipa, manda il link a dieci persone, quelle aprono la foto,
/// si registrano per poter accendere la fiamma, e restano. **Chi ha qualcosa in
/// gara ha un motivo vero per portare gente dentro** — non lo fa per farci un
/// favore, lo fa perche' vuole vincere.
///
/// Il link porta alla foto, non alla home: chi lo apre deve vedere subito la
/// cosa di cui gli hanno parlato. Da li' la challenge e' un tocco sotto.
abstract final class ShareEntry {
  /// Dove vive CRASY.
  ///
  /// Sul web si legge l'indirizzo da cui la pagina e' stata aperta, invece di
  /// scriverlo fisso: cosi' un link condiviso da una prova in locale porta alla
  /// prova in locale, e non manda chi lo riceve su un'app diversa da quella che
  /// chi condivide sta guardando.
  static String get origin {
    if (kIsWeb) {
      return Uri.base.origin;
    }

    return 'https://crasyapp.com';
  }

  /// L'indirizzo di una singola partecipazione.
  ///
  /// **Sul telefono lo apre l'app, non il browser** — come fa un link di TikTok
  /// mandato su WhatsApp. Reggono su questo indirizzo due file serviti da
  /// crasyapp.com (`apple-app-site-association` e `assetlinks.json`) che dicono
  /// ai due sistemi operativi che `/foto` appartiene a CRASY. Il resto del
  /// dominio no: la vetrina e l'informativa restano un sito.
  ///
  /// **Chi l'app non ce l'ha atterra sul sito, che pero' la foto non la
  /// mostra.** Il contenuto di CRASY sta dentro CRASY: una pagina web che
  /// facesse vedere la foto sarebbe una seconda app nel browser, e chi la
  /// riceve guarderebbe e se ne andrebbe senza scaricare niente e senza poter
  /// votare — cioe' senza dare la fiamma, che e' la ragione per cui quel link
  /// e' stato mandato.
  ///
  /// Percio' il link **non porta il file**, solo i due nomi da scrivere: la
  /// missione e chi ci ha partecipato. Bastano a far capire cosa si sta per
  /// aprire, e non fanno vedere niente.
  ///
  /// Prima era `crasy.web.app/#/challenge/...`, cioe' l'app dentro il browser.
  /// Da quando il dominio serve la vetrina, quel link atterrava sulla pagina di
  /// presentazione e **la foto non si vedeva da nessuna parte**: chi la riceveva
  /// non sapeva nemmeno cosa gli fosse stato mandato.
  static String linkTo({
    required String challengeId,
    required String entryId,
    String challengeTitle = '',
    String authorName = '',
  }) {
    final coda = <String, String>{
      'g': challengeId,
      'f': entryId,
      if (challengeTitle.isNotEmpty) 't': challengeTitle,
      if (authorName.isNotEmpty) 'a': authorName,
    };

    return Uri.parse(
      '$origin${AppRoutes.sharedEntry}',
    ).replace(queryParameters: coda).toString();
  }

  /// Il messaggio gia' scritto, con il link in fondo.
  ///
  /// E' una **richiesta**, non una descrizione: "guarda la mia foto" non fa
  /// fare niente a nessuno, "dammi una fiamma" si'. Chi condivide sta chiedendo
  /// un voto, e la frase deve dire quello.
  static String messageFor({
    required String challengeId,
    required String entryId,
    required String challengeTitle,
    String authorName = '',
    bool ended = false,
  }) {
    final title = challengeTitle.isEmpty
        ? 'una challenge'
        : '"${challengeTitle.toUpperCase()}"';

    final link = linkTo(
      challengeId: challengeId,
      entryId: entryId,
      challengeTitle: challengeTitle,
      authorName: authorName,
    );

    // **A gara finita si chiede un'altra cosa, perche' non c'e' piu' niente
    // da chiedere.** "Dammi una fiamma" su una foto che non si puo' piu'
    // votare manda chi lo riceve a cercare un comando che non c'e', e fa fare
    // a chi condivide la figura di chi non sa come funziona la sua stessa
    // app. Li' la foto non e' piu' in gara: e' andata come e' andata, e si
    // guarda.
    if (ended) {
      return 'Guarda com\'è finita $title su CRASY.\n\n$link';
    }

    return 'Sono in gara su CRASY con $title. Aprila e dammi una fiamma: '
        'vince chi ne prende di più.\n\n$link';
  }

  /// Apre il pannello di condivisione, e **se non c'e' copia il link**.
  ///
  /// Il pannello del sistema non esiste dappertutto: su un browser da computer
  /// spesso non c'e', e dove c'e' puo' rifiutarsi di aprirsi. Prima il tasto in
  /// quei casi non faceva niente — nessun pannello, nessun messaggio, nessun
  /// modo di capire se era rotto o se era stato premuto male.
  ///
  /// Adesso il caso peggiore e' il messaggio negli appunti e una riga che lo
  /// dice: da li' si incolla dove si vuole, ed e' esattamente cio' che il
  /// pannello avrebbe fatto con un passaggio in meno.
  static Future<void> send(
    BuildContext context, {
    required String challengeId,
    required String entryId,
    required String challengeTitle,
    String authorName = '',
    bool ended = false,
  }) async {
    final message = messageFor(
      challengeId: challengeId,
      entryId: entryId,
      challengeTitle: challengeTitle,
      authorName: authorName,
      ended: ended,
    );

    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'La mia foto su CRASY',
          // Su iPad il pannello si aggancia a un punto dello schermo, e senza
          // saperlo il sistema non lo apre affatto.
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );

      if (result.status != ShareResultStatus.unavailable) {
        return;
      }
    } on Object {
      // Si passa agli appunti.
    }

    await Clipboard.setData(ClipboardData(text: message));

    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Messaggio copiato: incollalo dove vuoi.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
