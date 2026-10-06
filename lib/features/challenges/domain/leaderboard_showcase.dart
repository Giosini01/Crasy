import 'package:crasy/features/challenges/domain/leaderboard.dart';

/// **I posti tenuti aperti nella classifica.**
///
/// Serve al lancio, e serve per un motivo che non ha niente a che fare con
/// l'apparenza: [Leaderboard] conta solo chi ha mosso dei soldi, quindi con tre
/// gare chiuse il podio ha un gradino e due buchi — e due buchi si leggono come
/// un caricamento andato male, non come un'app nuova.
///
/// ## Prima qui c'era gente inventata, e si vedeva
///
/// Quattro nomi con una faccia disegnata e centoventi euro di vincite a testa.
/// Il guaio non era l'imbroglio — e' una vetrina, non un bilancio — era che
/// **coprivano i veri**: chi aveva vinto novanta centesimi finiva quinto, sotto
/// quattro persone che non esistono, e l'unica vincita vera dell'app non si
/// vedeva nemmeno. Una vetrina che nasconde la merce.
///
/// Adesso i posti sono **account veri a zero**. Tengono su il podio quando non
/// c'e' ancora niente, e appena qualcuno vince un centesimo gli passa davanti da
/// solo: zero e' il fondo della classifica, quindi non c'e' piu' niente che
/// possa stare sopra una vincita vera.
///
/// Si spengono mettendo `false` qui, e il giorno in cui le gare chiuse bastano a
/// riempire i due podi e' la cosa giusta da fare.
const bool classificaVetrina = true;

/// Un posto tenuto aperto: di chi e', e con che conti ci sta.
class ShowcaseSeat {
  const ShowcaseSeat({required this.username, this.cents = 0, this.count = 0});

  /// Il nome esatto dell'account. Si cerca, e trovandolo la riga prende la sua
  /// faccia vera e porta al suo profilo.
  final String username;

  /// **Zero, e non e' un valore da riempire.** Un posto con dei soldi dentro e'
  /// un posto che passa davanti a qualcuno che li ha presi davvero.
  final int cents;

  final int count;
}

/// **I nomi sono quelli veri, e per un po' non lo erano.**
///
/// C'era scritto `giosini` e `frankk`. Quei due account **non esistono**: i nomi
/// giusti sono `giosyni` e `franksy`, e si vedono scorrendo i profili veri. Prima
/// non si notava perche' un posto che non trovava il suo account restava comunque
/// in classifica, con una faccia disegnata e nessun profilo dietro; da quando chi
/// non si trova resta fuori, quei due erano **due posti che non comparivano** — e
/// il podio restava vuoto, cioe' esattamente la cosa che questi posti esistono per
/// evitare.
///
/// Un nome sbagliato qui non da' nessun errore: da' una classifica vuota. Chi li
/// cambia controlli che l'account esista davvero.
const vincitoriVetrina = <ShowcaseSeat>[
  ShowcaseSeat(username: 'giosyni'),
  ShowcaseSeat(username: 'franksy'),
];

/// Chi ha messo di piu' in palio.
const chiFaGiocareVetrina = <ShowcaseSeat>[
  ShowcaseSeat(username: 'giosyni'),
  ShowcaseSeat(username: 'franksy'),
];

/// Le righe vere con in mezzo i posti tenuti aperti, nello stesso ordine della
/// classifica: prima i soldi, poi le volte, poi il nome.
///
/// `trovati` porta l'identificativo degli account, per nome. Chi e' gia' in
/// classifica per davvero **non si ripete**: la sua riga vera, con i suoi soldi,
/// vince sul posto a zero.
///
/// Un posto il cui account non si trova si lascia fuori: una riga con un nome e
/// nessuna faccia, che non porta a nessun profilo, e' un buco scritto.
List<LeaderRow> conVetrina(
  List<LeaderRow> vere,
  List<ShowcaseSeat> vetrina,
  Map<String, String> trovati, {
  bool accesa = classificaVetrina,
}) {
  if (!accesa) {
    return vere;
  }

  final gia = {for (final riga in vere) riga.username.toLowerCase()};
  final righe = [
    ...vere,
    for (final posto in vetrina)
      if (!gia.contains(posto.username.toLowerCase()) &&
          (trovati[posto.username] ?? '').isNotEmpty)
        LeaderRow(
          userId: trovati[posto.username]!,
          username: posto.username,
          cents: posto.cents,
          count: posto.count,
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
