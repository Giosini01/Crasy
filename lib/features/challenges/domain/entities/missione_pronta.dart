import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';

/// **Una missione già scritta, da lanciare con un tocco.**
///
/// ## Il problema che risolve
///
/// Partecipare è **reagire**: l'idea l'ha messa un altro, tu scatti. Lanciare è
/// **inventare**: serve un'idea, va scritta bene, e si scopre solo dopo se
/// faceva ridere. È un lavoro, e per di più si paga.
///
/// È per questo che in ogni app di questo tipo c'è un creatore ogni cento
/// spettatori, e non si risolve abbassando il prezzo: chi non ha un'idea
/// continua a non averla anche a cinquanta centesimi.
///
/// Queste tolgono l'invenzione. Si sfoglia, se ne trova una che fa ridere, si
/// tocca, e il modulo è già compilato: restano il premio e il tasto. Il foglio
/// bianco diventa un menù.
///
/// **Chi un'idea ce l'ha continua a scriversela**: i campi restano quelli, si
/// scorre oltre e si batte la propria. Qui si smette solo di chiedere a tutti
/// di essere autori.
///
/// ## Come sono scelte
///
/// Tre regole, che sono le stesse che la riga di consiglio dà a chi scrive:
///
/// - **si fanno adesso**, con quello che uno ha intorno. Una missione che
///   chiede di andare da qualche parte non la fa nessuno prima di stasera;
/// - **sono un po' imbarazzanti, non difficili**. Chi guarda vuole vedere
///   qualcuno che ci ha provato, non qualcuno che è bravo;
/// - **si capiscono dal titolo**, senza aprire. Spesso è l'unica cosa che si
///   legge.
class MissionePronta {
  const MissionePronta({
    required this.titolo,
    required this.consegna,
    this.mediaKind = MediaKind.photo,
    this.source = ChallengeSource.instant,
  });

  /// Il titolo, già nella forma in cui finirà nella gara.
  ///
  /// Sta sotto i sessanta caratteri che il modulo accetta, e c'è un controllo
  /// che lo verifica: una missione pronta che non passa la validazione del
  /// modulo è peggio di nessuna missione pronta — si tocca, si compila da
  /// sola, e il tasto per mandarla resta spento senza che si capisca perché.
  final String titolo;

  /// La consegna: cosa deve fare chi partecipa, in una riga.
  final String consegna;

  final MediaKind mediaKind;

  /// Quasi tutte sono **istantanee**, e non è una svista: è quello che CRASY
  /// è. Le poche d'archivio ci sono perché chiedono una cosa che adesso non si
  /// può fare — una foto di dieci anni fa non si scatta.
  final ChallengeSource source;

  /// **Quelle di oggi: le stesse per tutti, diverse domani.**
  ///
  /// L'elenco e' sempre quello, cambia l'ordine — e cambia **una volta al
  /// giorno**, non a ogni apertura.
  ///
  /// ## Perche' non a caso ogni volta
  ///
  /// Un ordine che cambia a ogni apertura e' un elenco che non si impara mai:
  /// uno vede una missione, esce per pensarci, rientra e non la ritrova piu'.
  /// E dentro la stessa schermata sarebbe peggio ancora — i campi qui sotto si
  /// riscrivono a ogni lettera battuta, e la fila si rimescolerebbe sotto le
  /// dita.
  ///
  /// ## Perche' le stesse per tutti
  ///
  /// Perche' due amici che si parlano devono aver visto la stessa cosa. *"Hai
  /// visto quella del portafoglio?"* deve voler dire qualcosa; se ognuno
  /// vedesse un ordine suo, quella frase non starebbe in piedi.
  ///
  /// ## Perche' cambiarlo
  ///
  /// Le prime tre sono le uniche che si vedono senza scorrere, e se sono
  /// sempre quelle, le altre ventisette non le guarda nessuno — e chi lancia
  /// due volte in una settimana si ritrova davanti lo stesso menu di prima.
  static List<MissionePronta> diOggi([DateTime? quando]) {
    final oggi = quando ?? DateTime.now();

    // Il giorno come un numero solo. Non l'ora: dentro la stessa giornata
    // l'ordine non si deve muovere.
    final seme = oggi.year * 10000 + oggi.month * 100 + oggi.day;

    final mescolate = [...tutte];

    // Un rimescolamento che dipende solo dal giorno: lo stesso giorno da' lo
    // stesso ordine su qualunque telefono, senza che nessuno debba metterselo
    // d'accordo con nessuno.
    mescolate.sort(
      (una, altra) => _posto(una, seme).compareTo(_posto(altra, seme)),
    );

    return mescolate;
  }

  /// Il posto di una missione nell'ordine di un certo giorno.
  ///
  /// Si usa `hashCode` della stringa? No: in Dart non e' garantito uguale fra
  /// un avvio e l'altro, quindi due telefoni potrebbero ordinarle in modo
  /// diverso lo stesso giorno. Questo conto invece da' sempre lo stesso
  /// numero.
  static int _posto(MissionePronta missione, int seme) {
    var somma = seme;

    for (final unita in missione.titolo.codeUnits) {
      somma = (somma * 31 + unita) % 1000000007;
    }

    return somma;
  }

  /// L'elenco che si vede quando si apre il lancio.
  ///
  /// L'ordine non è casuale: in cima quelle che si fanno **senza alzarsi dal
  /// divano**, perché la prima che si legge decide se si continua a scorrere o
  /// si chiude.
  static const List<MissionePronta> tutte = [
    MissionePronta(
      titolo: 'COM\'È MESSA LA TUA SCRIVANIA',
      consegna:
          'Fotografa la scrivania dove sei adesso, così com\'è. Vietato '
          'sistemare niente prima.',
    ),
    MissionePronta(
      titolo: 'COSA C\'È NEL TUO FRIGO',
      consegna: 'Apri il frigo e scatta. Vince il più disperato.',
    ),
    MissionePronta(
      titolo: 'LA TUA FACCIA ADESSO',
      consegna:
          'Un selfie in questo momento, com\'è venuto. Niente filtri e '
          'niente secondo tentativo.',
    ),
    MissionePronta(
      titolo: 'LA SCARPA PIÙ DISTRUTTA CHE HAI',
      consegna:
          'Vai a prenderla, mettila a terra e fotografala. Più è messa male '
          'meglio è.',
    ),
    MissionePronta(
      titolo: 'IL TUO ANIMALE MENTRE FA UNA COSA STUPIDA',
      consegna:
          'Aspetta il momento e scatta. Se non hai un animale, va bene anche '
          'quello di qualcun altro.',
    ),
    MissionePronta(
      titolo: 'COME SEI VESTITO IN QUESTO MOMENTO',
      consegna:
          'Una foto di quello che hai addosso adesso. Non vale cambiarsi, e '
          'si vede.',
    ),
    MissionePronta(
      titolo: 'VESTITI COME TUA MADRE',
      consegna:
          'Mettiti addosso qualcosa che metterebbe lei e fatti una foto. '
          'L\'imitazione conta più dei vestiti.',
    ),
    MissionePronta(
      titolo: 'BALLA PER DIECI SECONDI',
      consegna:
          'Un video dove balli, dove sei adesso. Più è fuori luogo il posto, '
          'meglio è.',
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'IMITA QUALCUNO CHE CONOSCIAMO TUTTI',
      consegna:
          'Dieci secondi di imitazione. Non dire chi è: si capisce o non si '
          'capisce.',
      mediaKind: MediaKind.video,
    ),
    MissionePronta(
      titolo: 'LA FOTO PIÙ BRUTTA CHE HAI IN GALLERIA',
      consegna:
          'Cercala davvero. Quella che non hai mai fatto vedere a nessuno.',
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'TU, DIECI ANNI FA',
      consegna: 'Una foto vecchia di te. Più è imbarazzante più vale.',
      source: ChallengeSource.archive,
    ),
    MissionePronta(
      titolo: 'IL POSTO PIÙ BELLO DOVE SEI STATO',
      consegna:
          'Una foto fatta da te, non presa da internet. Si vede la '
          'differenza.',
      source: ChallengeSource.archive,
    ),
  ];
}
