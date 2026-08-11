import 'package:app_incontri/features/feed/domain/entities/feed_item.dart';

abstract class FeedRepository {
  /// Le Daily che [userId] puo' vedere nel giorno [dateKey], gia' scelte dal
  /// server e ordinate dalla piu' vicina.
  Stream<List<FeedItem>> watchFeed(String userId, String dateKey);

  /// Le persone su cui [userId] si e' gia' espresso, cuore o scarto.
  ///
  /// Servono a togliere dal mazzo chi e' gia' stato valutato, senza rivelare
  /// in che senso: e' un insieme di identificativi, non di giudizi.
  Stream<Set<String>> watchDecidedUserIds(String userId);

  /// Registra la scelta. Non e' ritrattabile: le regole vietano di
  /// riscriverla, altrimenti si potrebbe sondare l'altro togliendo e
  /// rimettendo il cuore.
  ///
  /// [message] e' la riga che si puo' allegare al cuore. **Non la vede
  /// nessuno** finche' il cuore non e' ricambiato: resta dentro la propria
  /// decisione, che nessun altro puo' leggere, e solo alla nascita del match
  /// il server la consegna. Cosi' scrivere non e' un rischio — chi ti passa
  /// oltre non sapra' mai che gli avevi scritto qualcosa.
  Future<void> recordDecision({
    required String userId,
    required String targetId,
    required bool liked,
    String? message,
  });

  /// Segna un'Istantanea come guardata.
  ///
  /// Si scrive sulla **propria** voce di feed, l'unico documento che chi
  /// guarda ha il diritto di toccare; da li' il server aggiunge uno sguardo a
  /// chi l'ha pubblicata. E' l'unica cosa che sa il client e non il server:
  /// nessuno, a parte questo dispositivo, sa che quella foto e' comparsa
  /// davvero sullo schermo.
  Future<void> markSeen({required String userId, required String dailyId});
}
