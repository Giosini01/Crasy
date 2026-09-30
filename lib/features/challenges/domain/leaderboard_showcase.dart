import 'package:crasy/features/challenges/domain/leaderboard.dart';

/// **La classifica di vetrina: accesa.**
///
/// Serve al lancio: con poche gare chiuse i due podi restano vuoti, e una
/// schermata vuota non fa venire voglia di giocare a nessuno. Qui si aggiungono
/// sei posti — tre per classifica — a quelli veri.
///
/// **Sono inventati**, tranne due account della casa, e vanno spenti appena le
/// gare vere bastano a riempire il podio: mettere `false` qui li toglie tutti,
/// senza toccare nient'altro.
const bool classificaVetrina = true;

/// Un posto di vetrina: chi, quanto, quante volte, e la faccia.
class ShowcaseSeat {
  const ShowcaseSeat({
    required this.username,
    required this.cents,
    required this.count,
    required this.photoUrl,
    this.account = false,
  });

  final String username;
  final int cents;
  final int count;

  /// La foto da mostrare se l'account non si trova, o non ne ha una.
  final String photoUrl;

  /// Se e' un account vero, da cercare per nome: allora la faccia e il tocco
  /// sul profilo sono quelli veri.
  final bool account;
}

/// La faccia di un posto inventato. Disegnata, non una persona vera: nessuno
/// si ritrova la propria foto accanto a una vincita che non ha mai fatto.
String _faccia(String seme, String sfondo) =>
    'https://api.dicebear.com/9.x/notionists/png?seed=$seme'
    '&size=128&backgroundColor=$sfondo';

/// Chi ha vinto di piu'.
final vincitoriVetrina = <ShowcaseSeat>[
  ShowcaseSeat(
    username: 'giosini',
    cents: 12000,
    count: 4,
    photoUrl: _faccia('giosini', 'ffd5dc'),
    account: true,
  ),
  ShowcaseSeat(
    username: 'frankk',
    cents: 8500,
    count: 3,
    photoUrl: _faccia('frankk', 'c0aede'),
    account: true,
  ),
  ShowcaseSeat(
    username: 'martina.rv',
    cents: 6000,
    count: 2,
    photoUrl: _faccia('martina', 'ffdfbf'),
  ),
];

/// Chi ha messo di piu' in palio.
final chiFaGiocareVetrina = <ShowcaseSeat>[
  ShowcaseSeat(
    username: 'ale.ferri',
    cents: 15000,
    count: 5,
    photoUrl: _faccia('alessandro', 'b6e3f4'),
  ),
  ShowcaseSeat(
    username: 'sofia_m',
    cents: 9000,
    count: 3,
    photoUrl: _faccia('sofia', 'd1d4f9'),
  ),
  ShowcaseSeat(
    username: 'davide.cst',
    cents: 5000,
    count: 2,
    photoUrl: _faccia('davide', 'ffd5dc'),
  ),
];

/// Le righe vere con in mezzo quelle di vetrina, nello stesso ordine della
/// classifica: prima i soldi, poi le volte, poi il nome.
///
/// `trovati` porta l'identificativo degli account veri, per nome: con quello
/// la riga mostra la foto vera e porta al profilo. Chi e' gia' in classifica
/// per davvero non si ripete.
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
      if (!gia.contains(posto.username.toLowerCase()))
        LeaderRow(
          userId: posto.account ? trovati[posto.username] ?? '' : '',
          username: posto.username,
          cents: posto.cents,
          count: posto.count,
          photoUrl: posto.photoUrl,
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
