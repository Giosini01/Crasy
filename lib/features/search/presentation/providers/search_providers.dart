import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quello che si sta cercando.
///
/// Lo scrive la schermata **dopo una pausa**, non a ogni tasto: ogni parola
/// nuova costa una query a Firestore, e digitare "marco" a raffica ne farebbe
/// cinque per trovare una persona sola.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Cosa si sta cercando.
///
/// **Non e' un modo di restringere i risultati: e' un modo di dire cosa si ha
/// in testa.** Chi cerca "milano" sta cercando una gara a cui partecipare
/// stasera oppure una persona che conosce, e sono due ricerche diverse che
/// finirebbero mescolate nella stessa lista.
///
/// Le gare aperte e quelle finite stanno separate per la stessa ragione: a una
/// gara chiusa non si puo' piu' partecipare, e trovarsela in mezzo alle altre
/// e' una speranza sprecata. Chi le cerca apposta le cerca per un motivo
/// diverso — rivedere com'e' andata.
enum SearchFilter {
  all('TUTTO'),
  liveChallenges('APERTE'),
  endedChallenges('FINITE'),
  people('PERSONE');

  const SearchFilter(this.label);

  final String label;

  bool get wantsChallenges => this != SearchFilter.people;

  bool get wantsPeople =>
      this == SearchFilter.all || this == SearchFilter.people;
}

final searchFilterProvider = StateProvider.autoDispose<SearchFilter>(
  (ref) => SearchFilter.all,
);

/// Il minimo per cercare, persone o gare che siano.
///
/// Una lettera sola risponde con tutto: fra le persone sarebbe mezzo database
/// ordinato alfabeticamente, fra le gare tutte quelle che hanno una parola che
/// comincia per quella lettera. In tutti e due i casi non e' un risultato, e'
/// un elenco.
const searchMinimumLength = 2;

String _normalize(String value) => value.trim().toLowerCase();

/// Le challenge che corrispondono, **aperte prima e concluse dopo**.
///
/// Non c'e' nessuna query: le gare aperte e quelle finite sono gia' in casa —
/// le guarda la home, le guarda la scheda dei vincitori — e cercare dentro
/// quello che si e' gia' letto costa zero letture e risponde mentre si scrive.
/// Il giorno in cui le challenge fossero migliaia questa e' la prima cosa da
/// rifare, e si rifa' qui dentro senza toccare la schermata.
///
/// Si cerca nel titolo, nella consegna, nel posto e nel nome di chi l'ha
/// lanciata: sono i quattro modi in cui uno si ricorda una gara che ha visto
/// passare — *"quella del cartello"*, *"quella a Milano"*, *"quella di luca"*.
/// Se [text] comincia per [needle], o se lo fa **una delle sue parole**.
///
/// **Non "contiene", e la differenza si vedeva alla prima lettera.** Cercando
/// `h` con il vecchio confronto uscivano tutte le gare del mondo: quella
/// lettera sta dentro *challenge*, dentro *che*, dentro mezza lingua italiana.
/// Una ricerca che risponde tutto non ha risposto niente.
///
/// Per parole e non solo dall'inizio della frase, perche' nessuno si ricorda
/// una gara dalla sua prima parola: *"quella del cartello"* si cerca scrivendo
/// `cartello`, e il titolo comincia per "Fotografa".
bool _startsWithWord(String text, String needle) {
  final lower = text.toLowerCase();

  if (lower.startsWith(needle)) {
    return true;
  }

  for (final word in lower.split(_wordBreak)) {
    if (word.startsWith(needle)) {
      return true;
    }
  }

  return false;
}

/// Tutto cio' che separa due parole: spazi, punteggiatura, simboli.
final _wordBreak = RegExp('[^a-z0-9àèéìòù]+');

bool _matches(Challenge challenge, String needle) {
  return _startsWithWord(challenge.title, needle) ||
      _startsWithWord(challenge.brief, needle) ||
      _startsWithWord(challenge.place, needle) ||
      _startsWithWord(challenge.createdByUsername, needle);
}

/// Le gare **aperte** che corrispondono.
final liveChallengeResultsProvider = Provider.autoDispose<List<Challenge>>((
  ref,
) {
  final needle = _normalize(ref.watch(searchQueryProvider));

  if (needle.length < searchMinimumLength ||
      !ref.watch(searchFilterProvider).wantsChallenges) {
    return const [];
  }

  if (ref.watch(searchFilterProvider) == SearchFilter.endedChallenges) {
    return const [];
  }

  final live = ref.watch(liveChallengesProvider).valueOrNull ?? const [];

  return [
    for (final challenge in live)
      if (_matches(challenge, needle)) challenge,
  ];
});

/// Le gare **finite** che corrispondono.
///
/// Sono quelle degli ultimi due giorni: piu' indietro non esistono nemmeno —
/// il server le cancella. Vedi `Challenge.winnersWindow`.
final endedChallengeResultsProvider = Provider.autoDispose<List<Challenge>>((
  ref,
) {
  final needle = _normalize(ref.watch(searchQueryProvider));
  final filter = ref.watch(searchFilterProvider);

  if (needle.length < searchMinimumLength ||
      !filter.wantsChallenges ||
      filter == SearchFilter.liveChallenges) {
    return const [];
  }

  final ended = ref.watch(endedChallengesProvider).valueOrNull ?? const [];

  return [
    for (final challenge in ended)
      if (_matches(challenge, needle)) challenge,
  ];
});

/// Le persone che corrispondono.
///
/// Torna vuoto senza Firebase configurato: i profili degli altri esistono solo
/// li'. Le challenge di prova invece si cercano lo stesso, ed e' giusto cosi' —
/// la schermata funziona a meta' invece di non funzionare.
final peopleResultsProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) async {
  final needle = _normalize(ref.watch(searchQueryProvider));

  if (needle.length < searchMinimumLength ||
      !ref.watch(searchFilterProvider).wantsPeople) {
    // Con un filtro sulle gare la ricerca delle persone non parte nemmeno: e'
    // una lettura su Firestore risparmiata a ogni parola scritta.
    return const [];
  }

  final repository = ref.watch(friendsRepositoryProvider);

  if (repository == null) {
    return const [];
  }

  final results = await repository.searchProfiles(needle);
  final me = ref.watch(currentUserIdProvider);

  // Se stessi no: il proprio profilo si apre dalla scheda in fondo, e trovarsi
  // fra i risultati di una ricerca e' solo una riga da saltare.
  return [
    for (final profile in results)
      if (profile.id != me) profile,
  ];
});
