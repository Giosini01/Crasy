import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/share/share_entry.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Mandare **una missione** fuori da CRASY.
///
/// E' la sorella di [ShareEntry], e le due cose non si confondono: quella
/// manda *la mia foto* e chiede una fiamma, questa manda *la gara* e chiede di
/// entrarci. Chi riceve la prima ha davanti una cosa gia' fatta da guardare;
/// chi riceve la seconda ha davanti una cosa da fare, con un premio scritto
/// sopra e un orologio che scorre.
///
/// ## Condividere non e' partecipare
///
/// **Questo file non tocca la missione.** Non la completa, non ne cambia lo
/// stato, non consuma la foto del giorno, non muove nessun contatore e non
/// scrive niente su Firestore: prende quattro stringhe, ne compone un
/// messaggio e apre il pannello del sistema. E' scritto qui, in un servizio
/// senza dipendenze dai repository, proprio perche' quella separazione sia
/// vera e non solo promessa — da qui dentro non c'e' **nessun modo** di
/// scrivere sul database, anche volendo.
abstract final class ShareChallenge {
  /// L'indirizzo di una missione.
  ///
  /// Passa dallo stesso percorso dei link alle foto — `/foto` — perche' e'
  /// l'unico indirizzo di crasyapp.com che i due sistemi operativi sanno
  /// consegnare all'app: sta scritto in `apple-app-site-association` e in
  /// `assetlinks.json`, e aggiungerne un secondo vorrebbe dire rimettere mano
  /// a tutti e due i file e aspettare che i sistemi se ne accorgano.
  ///
  /// La differenza sta nella coda: qui c'e' la gara e **non** c'e' la foto.
  /// L'app lo legge come "portami su questa missione", il sito come "qualcuno
  /// ti ha invitato a una sfida".
  static String linkTo({
    required String challengeId,
    String challengeTitle = '',
  }) {
    final coda = <String, String>{
      'g': challengeId,
      if (challengeTitle.isNotEmpty) 't': challengeTitle,
    };

    return Uri.parse(
      '${ShareEntry.origin}${AppRoutes.sharedEntry}',
    ).replace(queryParameters: coda).toString();
  }

  /// Il messaggio gia' scritto, con il link in fondo.
  ///
  /// **E' un invito, non una descrizione.** "Guarda questa challenge" non fa
  /// fare niente a nessuno; il premio, la consegna e il tempo che resta sono
  /// le tre cose che fanno decidere — le stesse tre che si leggono per prime
  /// su ogni scheda della home, nello stesso ordine.
  static String messageFor({
    required String challengeId,
    required String challengeTitle,
    required int prizeCents,
    String brief = '',
    bool ended = false,
  }) {
    final title = challengeTitle.trim().isEmpty
        ? 'una missione'
        : '"${challengeTitle.trim().toUpperCase()}"';

    final link = linkTo(challengeId: challengeId, challengeTitle: challengeTitle);

    // A missione chiusa non c'e' piu' niente da proporre: chiedere di entrare
    // in una gara finita manda chi riceve a cercare un comando che non c'e', e
    // fa fare a chi condivide la figura di chi non sa come funziona la sua
    // stessa app.
    if (ended) {
      return 'Guarda com\'è finita $title su CRASY.\n\n$link';
    }

    final premio = prizeCents > 0
        ? 'In palio ${AppMoney.format(prizeCents)}.'
        : 'È gratis.';

    final consegna = brief.trim().isEmpty ? '' : '\n${brief.trim()}';

    return 'Su CRASY c\'è $title. $premio Entra e prova a vincere.'
        '$consegna\n\n$link';
  }

  /// Apre il pannello di condivisione, e **se non c'e' copia il link**.
  ///
  /// Stessa strada di [ShareEntry.send], e per la stessa ragione: su un
  /// browser da computer il pannello di sistema spesso non esiste, e prima il
  /// tasto in quei casi non faceva niente — nessun pannello, nessun messaggio,
  /// nessun modo di capire se era rotto o se era stato premuto male.
  static Future<void> send(
    BuildContext context, {
    required String challengeId,
    required String challengeTitle,
    required int prizeCents,
    String brief = '',
    bool ended = false,
  }) async {
    final message = messageFor(
      challengeId: challengeId,
      challengeTitle: challengeTitle,
      prizeCents: prizeCents,
      brief: brief,
      ended: ended,
    );

    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Una missione su CRASY',
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
