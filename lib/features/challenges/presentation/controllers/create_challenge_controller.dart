import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le regole di cosa puo' essere una challenge.
///
/// Stanno qui e non dentro la schermata perche' le stesse identiche condizioni
/// sono scritte anche nelle regole di Firestore: quello che si vede nel modulo
/// deve combaciare con quello che il database accetta, altrimenti si compila
/// tutto per poi vedersi rifiutare l'invio senza capire perche'.
abstract final class ChallengeDraftValidators {
  static const int titleMinLength = 3;
  static const int titleMaxLength = 60;
  static const int briefMaxLength = 280;

  /// Il premio massimo, in euro. Un milione: non e' una cifra realistica, e'
  /// un tetto contro le dita che scivolano sulla tastiera.
  static const int prizeMaxEuro = 1000000;

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

    return ContentPolicy.validate(title);
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
    return ContentPolicy.validate(brief);
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
      return 'Il premio minimo e\' ${AppMoney.format(prizeMinCents)}.';
    }

    if (cents > prizeMaxEuro * 100) {
      return 'Troppo. Il massimo e\' $prizeMaxEuro euro.';
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
        ? 'Scrivi la citta\' della challenge.'
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
    required MediaKind mediaKind,
    required String place,
    required int minutes,
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
      mediaKind: mediaKind,
      place: scope == ChallengeScope.local ? place.trim().toUpperCase() : '',
      // **Chi la puo' vedere, scritto dentro la gara.**
      //
      // Per una gara riservata: io e i miei amici di adesso. La fotografia si
      // scatta al momento del lancio e non cambia piu' — un amico fatto domani
      // non vedra' la gara di oggi, ed e' voluto: chi entra a meta' partita non
      // ha visto la sfida da cui e' nata.
      audience: scope == ChallengeScope.friends
          ? [
              authState.user.id,
              for (final amico
                  in ref.read(myFriendsProvider).valueOrNull ?? const [])
                amico.userId,
            ]
          : const [Challenge.everyone],
      createdByUsername: profile?.username ?? 'anonimo',
      createdByUserId: authState.user.id,
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
