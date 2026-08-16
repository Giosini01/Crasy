/// Cosa non si puo' chiedere alla gente di fare, e cosa non si puo' scrivere.
///
/// Questa e' la parte piu' importante del prodotto, e per un motivo preciso:
/// CRASY **paga la gente per fare cose**. Una challenge non e' un post, e' un
/// incarico con un premio in denaro, e un incarico sbagliato — *tagliati*,
/// *sali sul cornicione*, *picchia qualcuno* — non e' un contenuto discutibile:
/// e' una persona che si fa male perche' gliel'abbiamo chiesto noi.
///
/// ## Cosa fa e cosa non fa
///
/// E' un elenco di parole. Ferma **il caso esplicito**, che e' anche il piu'
/// probabile: qualcuno che scrive una cosa del genere per gioco o per provocare.
/// Non ferma chi cerca di aggirarlo, e non capisce il contesto — "questo film mi
/// ha ucciso" e' innocuo, e questa funzione non lo sa.
///
/// Quindi **non e' la moderazione**: e' la prima delle tre porte.
///
/// 1. qui, subito, prima ancora di scrivere sul database;
/// 2. le regole di Firestore, che rifiutano i casi piu' espliciti anche se
///    qualcuno scrivesse saltando l'app;
/// 3. un controllo automatico sul server, e prima o poi degli occhi umani.
///
/// Una lista di parole da sola darebbe una falsa sicurezza. In fondo alla
/// catena serve qualcuno che guardi, e va messo in conto prima di aprire al
/// pubblico.
abstract final class ContentPolicy {
  /// Perche' un testo e' stato rifiutato.
  ///
  /// Sapere **quale** categoria e' stata toccata serve a dire alla persona una
  /// frase sensata invece di un "non consentito" che non spiega niente.
  static const selfHarm = ContentViolation._(
    'autolesionismo',
    'Non si puo\' chiedere a nessuno di farsi del male. Se stai passando un '
        'momento difficile, in Italia il Telefono Amico risponde al 02 2327 '
        '2327.',
  );

  static const violence = ContentViolation._(
    'violenza',
    'Non si puo\' chiedere a nessuno di fare del male a qualcun altro, o a un '
        'animale.',
  );

  static const sexual = ContentViolation._(
    'sesso',
    'Niente contenuti sessuali o nudita\': su CRASY non sono ammessi.',
  );

  static const danger = ContentViolation._(
    'pericolo',
    'Questa challenge chiede qualcosa che puo\' finire male davvero. Non e\' '
        'quel tipo di app.',
  );

  static const hate = ContentViolation._(
    'odio',
    'Niente insulti o attacchi a una persona o a un gruppo.',
  );

  /// Le espressioni che fanno scattare ogni categoria.
  ///
  /// Sono scritte come frammenti perche' l'italiano coniuga: `ammazzat` prende
  /// "ammazzati" e "ammazzatevi". Il prezzo sono i falsi positivi — una parola
  /// dentro un'altra parola — che si paga volentieri: rifiutare per sbaglio una
  /// challenge innocua costa a chi la scrive trenta secondi, lasciar passare
  /// "tagliati le vene" costa molto di piu'.
  static const Map<ContentViolation, List<String>> _patterns = {
    selfHarm: [
      'suicid',
      'suicidi',
      'ammazzat',
      'uccidit',
      'uccidet',
      'tagliati le vene',
      'tagliarsi le vene',
      'tagliati i polsi',
      'fine alla tua vita',
      'fine alla vita',
      'farla finita',
      'impiccat',
      'impiccar',
      'autolesion',
      'fatti del male',
      'farti del male',
      'farsi del male',
      'fatevi del male',
      'ferisciti',
      'feritevi',
      'bruciati',
      'affogat',
      'buttati di sotto',
      'buttarsi di sotto',
      'lanciati dal',
      'salta dal balcone',
      'salta dalla finestra',
      'overdose',
      'bevi la candeggina',
      'ingoia',
      'kill yourself',
      'kys',
      'self harm',
      'suicide',
      'cut yourself',
    ],
    violence: [
      'picchia',
      'menare qualcuno',
      'accoltell',
      'spara a',
      'aggredisci',
      'aggredire qualcuno',
      'ammazza il',
      'ammazza la',
      'uccidi ',
      'torturare',
      'tortura ',
      'sfregia',
      'maltratta',
      'investi con l',
      'dai fuoco a',
      'beat someone',
      'stab',
      'shoot someone',
    ],
    sexual: [
      'nud',
      'nuda',
      'nudo',
      'spogliat',
      'spogliar',
      'senza vestiti',
      'mutande',
      'intimo addosso',
      'seno scoperto',
      'genital',
      'porno',
      'masturb',
      'atto sessuale',
      'rapporto sessuale',
      'nude',
      'naked',
      'nsfw',
      'strip',
    ],
    danger: [
      'guida ubriac',
      'guidare ubriac',
      'contromano',
      'attraversa i binari',
      'sui binari',
      'sul cornicione',
      'sul tetto del treno',
      'appeso fuori dal',
      'in mezzo alla strada',
      'pastiglie',
      'farmaci a caso',
      'benzina addosso',
      'gioco del soffocamento',
      'trattieni il respiro finche',
    ],
    hate: [
      'sei un ritardat',
      'negr',
      'froci',
      'ricchion',
      'zingar',
      'terron',
      'handicappat',
      'ebrei di merda',
    ],
  };

  /// La prima violazione trovata in [text], oppure `null` se e' pulito.
  ///
  /// Il confronto e' su testo minuscolo e senza accenti: chi scrive "UCCIDITI"
  /// o "uccìditi" sta scrivendo la stessa cosa, e una lista che si fa aggirare
  /// da un tasto maiuscolo non serve a niente.
  static ContentViolation? check(String? text) {
    final normalized = _normalize(text ?? '');

    if (normalized.isEmpty) {
      return null;
    }

    for (final entry in _patterns.entries) {
      for (final pattern in entry.value) {
        if (normalized.contains(pattern)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Comodo per i moduli: torna il messaggio da mostrare, o `null`.
  static String? validate(String? text) => check(text)?.message;

  /// Controlla piu' pezzi insieme — titolo e consegna — e torna il primo
  /// problema.
  static ContentViolation? checkAll(Iterable<String?> texts) {
    for (final text in texts) {
      final violation = check(text);

      if (violation != null) {
        return violation;
      }
    }

    return null;
  }

  static const _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
  };

  static String _normalize(String text) {
    final buffer = StringBuffer();

    for (final char in text.toLowerCase().split('')) {
      buffer.write(_accents[char] ?? char);
    }

    return buffer.toString();
  }
}

/// Una regola violata, con la frase da mostrare a chi l'ha violata.
class ContentViolation {
  const ContentViolation._(this.category, this.message);

  /// Come si chiama la categoria, per i registri e per le prove.
  final String category;

  /// Cosa leggera' la persona. Spiega **perche'**, e nel caso piu' delicato
  /// offre un numero da chiamare invece di limitarsi a chiudere la porta.
  final String message;

  @override
  String toString() => 'ContentViolation($category)';
}
