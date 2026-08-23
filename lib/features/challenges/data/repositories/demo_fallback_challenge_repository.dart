import 'dart:typed_data';

import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';

/// Firestore davanti, le challenge di esempio dietro.
///
/// Regge il caso che un prodotto nuovo ha sempre: **il database e' collegato ma
/// dentro non c'e' ancora niente**. Senza questo strato l'app sarebbe vuota
/// fino al primo inserimento a mano, e non ci sarebbe modo di guardarla.
///
/// La regola e' una sola e vale in tutte le direzioni: se Firestore ha
/// challenge, si vedono quelle e gli esempi spariscono del tutto. Non si
/// mescolano mai — un elenco meta' vero e meta' finto sarebbe peggio di
/// entrambe le cose.
///
/// In scrittura non c'e' ambiguita': l'identificativo dice da solo dove va a
/// finire. Gli esempi hanno un id che comincia per `demo-` e restano in
/// memoria; tutto il resto va su Firestore.
class DemoFallbackChallengeRepository implements ChallengeRepository {
  DemoFallbackChallengeRepository(this._remote, this._samples);

  final ChallengeRepository _remote;
  final SampleChallengeRepository _samples;

  bool _isDemo(String challengeId) => _samples.owns(challengeId);

  ChallengeRepository _forChallenge(String challengeId) =>
      _isDemo(challengeId) ? _samples : _remote;

  @override
  Stream<List<Challenge>> watchLiveChallenges() {
    return _remote.watchLiveChallenges().asyncExpand((remote) {
      return remote.isEmpty
          ? _samples.watchLiveChallenges()
          : Stream.value(remote);
    });
  }

  @override
  Stream<List<Challenge>> watchEndedChallenges() {
    return _remote.watchEndedChallenges().asyncExpand((remote) {
      return remote.isEmpty
          ? _samples.watchEndedChallenges()
          : Stream.value(remote);
    });
  }

  @override
  Stream<Challenge?> watchChallenge(String challengeId) {
    return _forChallenge(challengeId).watchChallenge(challengeId);
  }

  @override
  Stream<List<ChallengeEntry>> watchEntries(String challengeId) {
    return _forChallenge(challengeId).watchEntries(challengeId);
  }

  @override
  Stream<List<ChallengeEntry>> watchEntriesByUser(String userId) {
    // Qui le due sorgenti si sommano invece di sostituirsi, ed e' l'unico
    // punto in cui succede: sono le partecipazioni di una persona, e se ha
    // mandato una foto a una challenge di esempio quella foto e' sua davvero.
    // Nasconderla perche' la challenge era finta sarebbe l'unica risposta
    // sbagliata possibile.
    return _remote.watchEntriesByUser(userId).asyncExpand((remote) {
      return _samples
          .watchEntriesByUser(userId)
          .map((demo) => [...remote, ...demo]);
    });
  }

  @override
  Future<Challenge> createChallenge(Challenge challenge) {
    // Le challenge nuove vanno **sempre** su Firestore, mai fra gli esempi:
    // una challenge lanciata da una persona vera deve poterla vedere anche
    // qualcun altro, ed e' esattamente cio' che gli esempi non sanno fare.
    return _remote.createChallenge(challenge);
  }

  @override
  Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required String userId,
    required String authorName,
    required Uint8List bytes,
    MediaKind mediaKind = MediaKind.photo,
    String? contentType,
  }) {
    return _forChallenge(challengeId).submitEntry(
      challengeId: challengeId,
      userId: userId,
      authorName: authorName,
      bytes: bytes,
      mediaKind: mediaKind,
      contentType: contentType,
    );
  }

  @override
  Future<void> setVote({
    required String challengeId,
    required String entryId,
    required String userId,
    required bool voted,
  }) {
    return _forChallenge(challengeId).setVote(
      challengeId: challengeId,
      entryId: entryId,
      userId: userId,
      voted: voted,
    );
  }

  @override
  Future<void> proclaimWinner({
    required String challengeId,
    required String winnerEntryId,
    required String winnerUserId,
    bool chosenByCreator = false,
  }) {
    return _forChallenge(challengeId).proclaimWinner(
      challengeId: challengeId,
      winnerEntryId: winnerEntryId,
      winnerUserId: winnerUserId,
      chosenByCreator: chosenByCreator,
    );
  }

  @override
  Stream<Set<String>> watchVotedEntryIds(String userId) {
    // I voti dati alle challenge vere e a quelle di esempio convivono: sono
    // insiemi di identificativi che non si sovrappongono mai, e all'interfaccia
    // serve un solo insieme per sapere quali cuori accendere.
    return _remote.watchVotedEntryIds(userId).asyncExpand((remote) {
      return _samples
          .watchVotedEntryIds(userId)
          .map((demo) => {...remote, ...demo});
    });
  }
}
