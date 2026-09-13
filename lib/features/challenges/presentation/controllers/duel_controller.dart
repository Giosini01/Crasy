import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Sfidare una persona sola, e rispondere a chi ha sfidato te.**
///
/// Sta a parte da `CreateChallengeController` perche' non e' lo stesso gesto:
/// li' si lancia una gara e si aspetta che entri qualcuno, qui si chiama
/// qualcuno per nome. Cambia chi la vede, cambia cosa succede dopo, e cambia
/// la cosa che chi la riceve deve fare — che in una gara normale non esiste
/// affatto.
///
/// **Una sfida mirata non tocca la giornata di nessuno.** Non toglie una delle
/// cinque partecipazioni a chi la lancia ne' a chi la riceve, non prende il
/// posto della sfida del giorno e non sposta nessun contatore: e' roba in
/// piu'. Il conto delle cinque lo tiene `livesLeftProvider`, che salta le
/// sfide mirate per lo stesso motivo per cui salta la sfida del giorno.
final duelControllerProvider = AsyncNotifierProvider<DuelController, void>(
  DuelController.new,
);

class DuelController extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Quanto dura una sfida fra amici, se non si dice altro.
  ///
  /// **Ventiquattro ore.** Una sfida lanciata la sera deve poter essere fatta
  /// il giorno dopo: con meno, chi la riceve mentre dorme la trova gia'
  /// scaduta, e una sfida che scade prima di essere letta e' peggio di una
  /// sfida non lanciata.
  static const Duration defaultDuration = Duration(hours: 24);

  /// Lancia una sfida a una persona.
  ///
  /// Torna l'identificativo della missione nata, o `null` se non e' andata.
  Future<String?> challenge({
    required String targetUserId,
    required String targetUsername,
    required String title,
    required String brief,
    MediaKind mediaKind = MediaKind.photo,
    ChallengeSource source = ChallengeSource.instant,
    Duration duration = defaultDuration,
  }) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      state = AsyncError<void>(
        StateError('Sessione non valida.'),
        StackTrace.current,
      );

      return null;
    }

    final meId = authState.user.id;

    // Sfidare se stessi non vuol dire niente, e produrrebbe una riga che
    // compare sia fra le lanciate sia fra le ricevute.
    if (targetUserId.isEmpty || targetUserId == meId) {
      state = AsyncError<void>(
        StateError('Scegli un amico da sfidare.'),
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
      // **Gratis, e non e' un risparmio.** Una sfida fra due amici vale per
      // conto suo: il premio e' la parola data. Mettere dei soldi in mezzo
      // trasformerebbe un gioco in un pagamento fra privati, con tutto quello
      // che comporta.
      prizeCents: 0,
      scope: ChallengeScope.friends,
      // Uno solo puo' partecipare: e' una sfida a lui, non una gara aperta.
      maxParticipants: 1,
      mediaKind: mediaKind,
      source: source,
      place: '',
      // **La vedono in due, e basta.** Nemmeno gli altri amici: una sfida
      // mirata e' una cosa fra due persone, e allargarla al gruppo sarebbe
      // un'altra funzione — quella c'e' gia', ed e' la missione di party.
      audience: [meId, targetUserId],
      createdByUsername: profile?.username ?? 'anonimo',
      createdByUserId: meId,
      targetUserId: targetUserId,
      targetUsername: targetUsername,
      duelStatus: DuelStatus.pending,
      startsAt: now,
      endsAt: now.add(duration),
    );

    state = const AsyncLoading<void>();

    final result = await AsyncValue.guard(
      () => ref.read(challengeRepositoryProvider).createChallenge(draft),
    );

    state = result.hasError
        ? AsyncError<void>(result.error!, result.stackTrace!)
        : const AsyncData<void>(null);

    final nata = result.valueOrNull;

    if (nata == null) {
      return null;
    }

    // **La notizia si manda da qui e non dal server**, come per le fiamme e i
    // commenti: chi lancia la sfida e' l'unico che lo sa nel momento in cui
    // succede. Il nome del documento porta dentro l'identificativo della
    // missione, quindi la stessa sfida non puo' suonare due volte.
    await _notify(
      toUserId: targetUserId,
      kind: NotificationKind.duel,
      challengeId: nata.id,
      challengeTitle: nata.title,
    );

    return nata.id;
  }

  /// Accetta una sfida: da qui in poi e' una parola data.
  ///
  /// **La stessa porta serve a chi ci ripensa.** Chi aveva detto di no e torna
  /// indietro passa di qui, e trova la sfida com'era: se nel frattempo il tempo
  /// era finito — e su un rifiuto e' quasi sempre cosi', perche' un no ferma la
  /// sfida ma non l'orologio — riparte da adesso con le ventiquattro ore
  /// intere. Riaprirla lasciandola scaduta vorrebbe dire riaprirla morta.
  Future<void> accept(Challenge challenge) {
    final now = DateTime.now();
    final riparte =
        challenge.duelStatus.isDeclined && !challenge.endsAt.isAfter(now);

    return _answer(
      challenge,
      DuelStatus.accepted,
      restartAt: riparte ? now.add(defaultDuration) : null,
    );
  }

  /// **Il giudizio di chi ha lanciato la sfida.**
  ///
  /// Chiude la sfida nel momento in cui arriva: non si aspetta nessuna
  /// scadenza, perche' su una sfida uno contro uno non c'e' niente che debba
  /// ancora succedere — la foto c'e' gia', e l'unica cosa che mancava era
  /// qualcuno che la guardasse.
  ///
  /// **E' un giudizio in buona fede, e non c'e' modo di renderlo altro.**
  /// Nessuna regola puo' obbligare una persona a essere onesta con un amico:
  /// quello che si puo' fare e' che il giudizio abbia un nome sopra, e ce
  /// l'ha. E' la stessa scommessa della sfida — chi accetta si impegna sulla
  /// parola, chi giudica risponde della sua.
  Future<void> judge(
    Challenge challenge, {
    required bool approved,
    ChallengeEntry? entry,
  }) async {
    final meId = ref.read(currentUserIdProvider);

    // **Giudica solo chi ha lanciato la sfida.** Lo stesso controllo sta nelle
    // regole di Firestore: qui evita un viaggio di rete per sentirsi dire di
    // no, li' e' quello che conta davvero.
    if (meId == null || meId != challenge.createdByUserId) {
      return;
    }

    if (!challenge.isDuel || challenge.duelVerdict.isGiven) {
      return;
    }

    state = const AsyncLoading<void>();

    final result = await AsyncValue.guard(
      () => ref
          .read(challengeRepositoryProvider)
          .judgeDuel(
            challengeId: challenge.id,
            approved: approved,
            entry: entry,
          ),
    );

    state = result.hasError
        ? AsyncError<void>(result.error!, result.stackTrace!)
        : const AsyncData<void>(null);

    if (result.hasError) {
      return;
    }

    await _notify(
      toUserId: challenge.targetUserId,
      kind: approved
          ? NotificationKind.duelApproved
          : NotificationKind.duelRejected,
      challengeId: challenge.id,
      challengeTitle: challenge.title,
    );
  }

  /// Rifiuta una sfida.
  Future<void> decline(Challenge challenge) =>
      _answer(challenge, DuelStatus.declined);

  /// Segna una sfida come portata a termine.
  ///
  /// Lo chiama la partecipazione, non un bottone: la sfida e' finita quando la
  /// foto e' in gara, e un tasto "l'ho fatta" separato dallo scatto sarebbe
  /// una promessa che chiunque puo' scrivere senza fare niente.
  Future<void> markCompleted(Challenge challenge) =>
      _answer(challenge, DuelStatus.completed);

  Future<void> _answer(
    Challenge challenge,
    DuelStatus status, {
    DateTime? restartAt,
  }) async {
    final meId = ref.read(currentUserIdProvider);

    // **Risponde solo chi e' stato sfidato.** La stessa condizione sta nelle
    // regole di Firestore: qui serve a non fare un viaggio di rete per
    // sentirsi dire di no.
    if (meId == null || meId != challenge.targetUserId) {
      return;
    }

    if (challenge.duelStatus == status) {
      return;
    }

    state = const AsyncLoading<void>();

    final result = await AsyncValue.guard(
      () => ref
          .read(challengeRepositoryProvider)
          .answerDuel(
            challengeId: challenge.id,
            status: status,
            restartAt: restartAt,
          ),
    );

    state = result.hasError
        ? AsyncError<void>(result.error!, result.stackTrace!)
        : const AsyncData<void>(null);

    if (result.hasError) {
      return;
    }

    // Chi l'ha lanciata deve sapere com'e' andata: e' l'altra meta' della
    // sfida, e senza questa riga resterebbe ad aspettare una risposta che nel
    // database c'e' gia'.
    await _notify(
      toUserId: challenge.createdByUserId,
      kind: switch (status) {
        DuelStatus.accepted => NotificationKind.duelAccepted,
        DuelStatus.declined => NotificationKind.duelDeclined,
        DuelStatus.completed => NotificationKind.duelCompleted,
        DuelStatus.pending => NotificationKind.duel,
      },
      challengeId: challenge.id,
      challengeTitle: challenge.title,
    );
  }

  /// Scrive una riga in campanella all'altra persona.
  ///
  /// **Il nome del documento e' la difesa contro i doppioni**, come per le
  /// fiamme: tipo piu' missione. Chi accetta, ci ripensa e riaccetta non fa
  /// suonare due volte lo stesso telefono — le regole rifiutano la
  /// riscrittura di una notifica che esiste gia'.
  Future<void> _notify({
    required String toUserId,
    required NotificationKind kind,
    required String challengeId,
    required String challengeTitle,
  }) async {
    final repository = ref.read(notificationsRepositoryProvider);
    final meId = ref.read(currentUserIdProvider);

    if (repository == null || meId == null || toUserId.isEmpty) {
      return;
    }

    await repository.push(
      toUserId: toUserId,
      id: FirestoreNotificationsRepository.duelId(
        kind: kind,
        challengeId: challengeId,
      ),
      kind: kind,
      actorId: meId,
      actorUsername:
          ref.read(currentUserProfileProvider).valueOrNull?.username ??
          'qualcuno',
      challengeId: challengeId,
      challengeTitle: challengeTitle,
    );
  }
}
