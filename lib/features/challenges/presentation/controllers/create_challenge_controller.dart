import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
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

  static String? validatePrize(String? value) {
    final euro = int.tryParse(value?.trim() ?? '');

    if (euro == null || euro <= 0) {
      return 'Inserisci il premio in euro.';
    }

    if (euro > prizeMaxEuro) {
      return 'Troppo. Il massimo e\' $prizeMaxEuro euro.';
    }

    return null;
  }

  /// Quanto puo' durare una challenge, in ore.
  ///
  /// Il tetto e' **un giorno**, e non e' un limite tecnico: e' il prodotto. Una
  /// gara che dura una settimana non ha nessuna urgenza, e l'urgenza e' meta'
  /// del motivo per cui uno esce di casa a fare una foto assurda. Il minimo e'
  /// un'ora perche' sotto non ci sta nemmeno il tempo di parteciparvi.
  static const int hoursMin = 1;
  static const int hoursMax = 24;

  static String? validateHours(String? value) {
    final hours = int.tryParse(value?.trim() ?? '');

    if (hours == null) {
      return 'Inserisci quante ore dura.';
    }

    if (hours < hoursMin || hours > hoursMax) {
      return 'Da $hoursMin a $hoursMax ore.';
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
    required int prizeEuro,
    required ChallengeScope scope,
    required String place,
    required int hours,
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
      // Il premio viaggia in centesimi, sempre. Qui si moltiplica una volta
      // sola, all'ingresso: da qui in poi nessuno deve piu' chiedersi se il
      // numero che ha in mano sono euro o centesimi.
      prizeCents: prizeEuro * 100,
      scope: scope,
      place: scope == ChallengeScope.local ? place.trim().toUpperCase() : '',
      createdByUsername: profile?.username ?? 'anonimo',
      createdByUserId: authState.user.id,
      startsAt: now,
      endsAt: now.add(Duration(hours: hours)),
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
