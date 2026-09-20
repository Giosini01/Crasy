import 'package:crasy/features/challenges/domain/entities/challenge.dart';

/// Una riga di classifica: una persona, quanto ha mosso, quante volte.
class LeaderRow {
  const LeaderRow({
    required this.userId,
    required this.username,
    required this.cents,
    required this.count,
  });

  final String userId;
  final String username;

  /// I soldi: vinti, per chi gareggia; messi in palio, per chi lancia.
  final int cents;

  /// Quante gare. **Serve a sciogliere i pari, non a fare la classifica.**
  final int count;
}

/// **Chi conta, adesso.**
///
/// Due classifiche con la stessa regola, ed e' una regola sola: **comandano i
/// soldi, non le presenze.** Chi ha vinto una gara da cento sta sopra a chi ne
/// ha vinte dieci da uno, e non e' una preferenza estetica — e' l'unica lettura
/// che non si possa gonfiare. Contare le partecipazioni premia chi entra
/// dappertutto senza rischiare niente; contare i soldi premia chi ha fatto la
/// cosa piu' difficile, che e' esattamente quello che una classifica dovrebbe
/// far venire voglia di fare.
///
/// Il numero di gare resta, ma solo **a parita' di soldi**: fra due persone che
/// hanno preso la stessa cifra, sta sopra quella che l'ha fatto piu' volte.
///
/// ## Perche' si calcola qui e non sul database
///
/// I dati sono gia' in mano all'app: sono le stesse gare chiuse che questa
/// schermata mostra sotto, lette una volta sola. Una classifica vera — un
/// contatore per persona, aggiornato a ogni vittoria — vorrebbe dire una
/// scrittura in piu' a ogni chiusura e un documento che prima o poi non torna
/// con la realta'. Questa si ricalcola da sola ogni volta, e non puo' essere
/// sbagliata: e' una somma di cose che esistono.
///
/// **Ed e' una classifica di adesso, non di sempre**, perche' le gare che le
/// passano davanti sono quelle delle ultime ore. E' quello che deve essere: in
/// tendenza vuol dire ora.
abstract final class Leaderboard {
  /// Chi ha **vinto** di piu'.
  ///
  /// Si somma il netto — quello che uno ha incassato davvero, non il premio in
  /// vetrina — perche' e' la cifra che quella persona puo' dire di avere.
  static List<LeaderRow> winners(List<Challenge> challenges) {
    final cents = <String, int>{};
    final quante = <String, int>{};
    final nomi = <String, String>{};

    for (final challenge in challenges) {
      final chi = challenge.winnerUserId;

      // Senza vincitore non c'e' niente da contare. E le gare gratis non
      // entrano: una classifica di soldi fatta anche con chi non ne ha presi
      // mette in mezzo due cose diverse.
      if (chi.isEmpty || challenge.payoutCents <= 0) {
        continue;
      }

      cents[chi] = (cents[chi] ?? 0) + challenge.payoutCents;
      quante[chi] = (quante[chi] ?? 0) + 1;
      nomi[chi] = challenge.winnerUsername;
    }

    return _inOrdine(cents, quante, nomi);
  }

  /// Chi ha **fatto giocare** di piu': i soldi messi in palio.
  ///
  /// E' l'altra meta' dell'app, e senza questa classifica non si vede da
  /// nessuna parte. Chi lancia una gara mette dei soldi e non puo' vincere
  /// niente: l'unico modo di rendergli merito e' contare quello che ha messo.
  static List<LeaderRow> launchers(List<Challenge> challenges) {
    final cents = <String, int>{};
    final quante = <String, int>{};
    final nomi = <String, String>{};

    for (final challenge in challenges) {
      final chi = challenge.createdByUserId;

      // Le sfide del giorno non hanno un autore e non costano niente: sono di
      // CRASY, e CRASY non gareggia nemmeno da questa parte.
      if (chi.isEmpty || challenge.prizeCents <= 0) {
        continue;
      }

      cents[chi] = (cents[chi] ?? 0) + challenge.prizeCents;
      quante[chi] = (quante[chi] ?? 0) + 1;
      nomi[chi] = challenge.createdByUsername;
    }

    return _inOrdine(cents, quante, nomi);
  }

  /// Prima i soldi, poi le volte, poi il nome.
  ///
  /// Il nome alla fine non e' un criterio: e' il modo di non avere una
  /// classifica che cambia ordine da sola a ogni ricostruzione fra due persone
  /// identiche.
  static List<LeaderRow> _inOrdine(
    Map<String, int> cents,
    Map<String, int> quante,
    Map<String, String> nomi,
  ) {
    final righe = [
      for (final chi in cents.keys)
        LeaderRow(
          userId: chi,
          username: nomi[chi] ?? '',
          cents: cents[chi]!,
          count: quante[chi] ?? 0,
        ),
    ];

    righe.sort((a, b) {
      final soldi = b.cents.compareTo(a.cents);

      if (soldi != 0) {
        return soldi;
      }

      final volte = b.count.compareTo(a.count);

      return volte != 0 ? volte : a.username.compareTo(b.username);
    });

    return righe;
  }
}
