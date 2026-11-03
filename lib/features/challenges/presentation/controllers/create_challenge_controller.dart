import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le regole di cosa puo' essere una challenge.
///
/// Stanno qui e non dentro la schermata perche' le stesse identiche condizioni
/// sono scritte anche sul server (`leggiLaRichiesta` in `functions/missioni.js`):
/// quello che si vede nel modulo deve combaciare con quello che il server accetta,
/// altrimenti si compila tutto per poi vedersi rifiutare l'invio senza capire
/// perche'.
///
/// **Le parole si guardano qui per dirlo subito a chi scrive, non per sicurezza.**
/// Un telefono si puo' modificare: l'ultima parola su una missione e' del server.
abstract final class ChallengeDraftValidators {
  static const int titleMinLength = 3;
  static const int titleMaxLength = 60;
  static const int briefMaxLength = 280;

  /// La riga per l'amico: la stessa misura del server.
  static const int duelMessageMaxLength = 140;

  /// **Il premio massimo, in euro: cento.** Lo stesso tetto sta sul server. Era un
  /// milione, come argine contro le dita che scivolano; adesso e' un limite vero,
  /// piu' alto di qualunque premio messo finora, e si alza tutti e due insieme.
  static const int prizeMaxEuro = 100;

  static String? validateTitle(String? value) {
    final title = value?.trim() ?? '';

    if (title.isEmpty) {
      return 'Dai un titolo alla challenge.';
    }

    if (title.length < titleMinLength) {
      return 'Almeno $titleMinLength caratteri.';
    }

    if (title.length > titleMaxLength) {
      return 'Al massimo $titleMaxLength caratteri.';
    }

    return ContentPolicy.validateMission(title);
  }

  static String? validateBrief(String? value) {
    final brief = value?.trim() ?? '';

    if (brief.isEmpty) {
      return 'Scrivi cosa bisogna fare.';
    }

    if (brief.length > briefMaxLength) {
      return 'Al massimo $briefMaxLength caratteri.';
    }

    // Qui il controllo pesa piu' che altrove, ed e' bene sapere perche'. Una
    // challenge non e' un post: e' **un incarico con un premio in denaro**. Una
    // consegna sbagliata — "tagliati", "sali sul cornicione" — non e' un
    // contenuto discutibile, e' una persona che si fa male perche' gliel'ha
    // chiesto la nostra app, in cambio di soldi nostri.
    //
    // Per questo e' `validateMission` e non `validate`: oltre all'elenco ferma
    // tutto quello che il database rifiuta in una missione, e le richieste
    // pericolose dette a giri di parole.
    return ContentPolicy.validateMission(brief);
  }

  /// La riga per l'amico, sulle sfide: facoltativa, ma non senza regole.
  ///
  /// E' l'unico posto dell'app in cui si scrive qualcosa che legge una persona
  /// sola, e proprio per questo non ha meno bisogno degli altri di un filtro: non
  /// la vede nessun altro che possa segnalarla.
  static String? validateDuelMessage(String? value) {
    final messaggio = value?.trim() ?? '';

    if (messaggio.length > duelMessageMaxLength) {
      return 'Al massimo $duelMessageMaxLength caratteri.';
    }

    return ContentPolicy.validate(messaggio);
  }

  /// Il premio piu' piccolo che si possa mettere: **un euro**.
  ///
  /// Un centesimo non e' un premio, e' una presa in giro — e con dei premi in
  /// denaro la presa in giro non e' un dettaglio estetico: una gara da un
  /// centesimo occupa in home lo stesso spazio di una da cinquanta euro, si
  /// mangia una delle cinque partecipazioni di chi ci casca, e insegna a tutti
  /// gli altri che il numero rosso in cima non vuol dire niente. Basta che
  /// succeda tre volte perche' nessuno guardi piu' quel numero.
  ///
  /// Un euro e' basso apposta: una gara fra amici deve restare possibile, e
  /// alzare l'asticella per fare i seri terrebbe fuori proprio le gare che
  /// riempiono l'app all'inizio. E' la soglia sotto la quale un premio smette
  /// di essere un premio, non un filtro sul valore.
  static const int prizeMinCents = 100;

  static String? validatePrize(String? value, {bool forFriends = false}) {
    // Il premio si scrive anche con i centesimi: `10,50`. Non e' un vezzo — a
    // dividere una cifra fra due persone i centesimi escono da soli, e un
    // campo che li rifiuta costringe ad arrotondare in favore di qualcuno.
    final cents = AppMoney.centsFrom(value);

    if (cents == null) {
      return 'Inserisci il premio in euro.';
    }

    // Il messaggio dice **il numero**, non "importo non valido": chi ha scritto
    // cinquanta centesimi deve sapere subito quanto deve alzare, non che ha
    // sbagliato qualcosa.
    // **Fra amici lo zero e' ammesso.** Una gara riservata vale gia' per conto
    // suo — la sfida e' il premio — e chiedere un euro per lanciarla metterebbe
    // un casello davanti alla cosa piu' naturale che si fa qui dentro. Fuori da
    // li' il minimo resta, perche' sotto un euro un premio non e' un premio.
    if (forFriends && cents == 0) {
      return null;
    }

    if (cents < prizeMinCents) {
      return 'Il premio minimo è ${AppMoney.format(prizeMinCents)}.';
    }

    if (cents > prizeMaxEuro * 100) {
      return 'Troppo. Il massimo è $prizeMaxEuro euro.';
    }

    return null;
  }

  /// Quanto puo' durare una challenge, **in minuti**.
  ///
  /// Il tetto e' un giorno, e non e' un limite tecnico: e' il prodotto. Una
  /// gara che dura una settimana non ha nessuna urgenza, e l'urgenza e' meta'
  /// del motivo per cui uno esce di casa a fare una foto assurda.
  ///
  /// Il minimo e' **un minuto**, ed e' li' per provare. Una gara di sessanta
  /// secondi non e' una gara — non ci sta il tempo di uscire di casa — ma e'
  /// l'unico modo di vedere il giro intero (si crea, si partecipa, si vota, si
  /// chiude, si proclama) senza restare seduti ad aspettare un'ora. Quando
  /// l'app sara' in mano a delle persone vere, il minimo torna a un'ora.
  static const int minutesMin = 1;
  static const int minutesMax = 24 * 60;

  static String? validateMinutes(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');

    if (minutes == null) {
      return 'Inserisci quanti minuti dura.';
    }

    if (minutes < minutesMin || minutes > minutesMax) {
      return 'Da $minutesMin a $minutesMax minuti.';
    }

    return null;
  }

  static String? validatePlace(ChallengeScope scope, String? value) {
    if (scope != ChallengeScope.local) {
      return null;
    }

    return (value?.trim() ?? '').isEmpty
        ? 'Scrivi la città della challenge.'
        : null;
  }
}

final createChallengeControllerProvider =
    AsyncNotifierProvider<CreateChallengeController, void>(
      CreateChallengeController.new,
    );

/// Lanciare una challenge.
class CreateChallengeController extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Crea la challenge e torna il suo identificativo, oppure `null` se non e'
  /// andata: chi chiama lo usa per aprire subito la challenge appena nata.
  Future<String?> create({
    required String title,
    required String brief,
    required int prizeCents,
    required ChallengeScope scope,
    required int maxParticipants,
    required MediaKind mediaKind,
    ChallengeSource source = ChallengeSource.instant,
    required String place,
    required int minutes,
    bool anonimo = false,
  }) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      state = AsyncError<void>(
        StateError('Sessione non valida.'),
        StackTrace.current,
      );

      return null;
    }

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final now = DateTime.now();

    final draft = Challenge(
      id: '',
      title: title.trim(),
      brief: brief.trim(),
      // Il premio viaggia in centesimi, sempre. La conversione si fa una
      // volta sola, dove si legge quello che e' stato scritto — vedi
      // `AppMoney.centsFrom` — e da li' in poi nessuno deve piu' chiedersi se
      // il numero che ha in mano sono euro o centesimi. Prima la
      // moltiplicazione stava qui, e bastava perche' il campo accettava solo
      // numeri interi.
      prizeCents: prizeCents,
      scope: scope,
      maxParticipants: maxParticipants,
      mediaKind: mediaKind,
      source: source,
      place: scope == ChallengeScope.local ? place.trim().toUpperCase() : '',
      // **Chi la puo' vedere, scritto dentro la gara.**
      //
      // Per una gara riservata: io e i miei amici di adesso. Vale per le gare
      // d'esempio: **quelle vere non lo mandano nemmeno**, l'elenco lo fa il server
      // quando la missione esce. Fra la scrittura e l'uscita possono passare delle
      // ore, e chi la puo' vedere non deve deciderlo un telefono.
      audience: scope == ChallengeScope.friends
          ? [
              authState.user.id,
              for (final amico
                  in ref.read(myFriendsProvider).valueOrNull ?? const [])
                amico.userId,
            ]
          : const [Challenge.everyone],
      // In anonimo il nome non parte: vedi `Challenge.anonimo`.
      createdByUsername: anonimo ? '' : profile?.username ?? 'anonimo',
      createdByUserId: authState.user.id,
      anonimo: anonimo,
      startsAt: now,
      endsAt: now.add(Duration(minutes: minutes)),
    );

    state = const AsyncLoading<void>();
    final result = await AsyncValue.guard(
      () => ref.read(challengeRepositoryProvider).createChallenge(draft),
    );

    state = result.hasError
        ? AsyncError<void>(result.error!, result.stackTrace!)
        : const AsyncData<void>(null);

    return result.valueOrNull?.id;
  }
}
