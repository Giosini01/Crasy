import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart'
    show AlreadyParticipatingException;
import 'package:crasy/features/challenges/domain/commissioned_order.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';

/// Le challenge tenute in memoria.
///
/// **Nasce vuoto, e ci resta finche' qualcuno non lancia una challenge.** Non
/// c'e' nessun dato di esempio: challenge finte in mezzo a quelle vere
/// confondono e basta, e una volta che il database c'e' non servono piu' a
/// niente.
///
/// A cosa serve allora: a far girare l'app **senza Firebase configurato**. Chi
/// clona il progetto puo' aprirlo, lanciare una challenge, partecipare e votare;
/// tutto vive in memoria e sparisce alla chiusura. Serve anche ai test, che
/// cosi' non hanno bisogno ne' di rete ne' di credenziali.
///
/// Con Firebase configurato questo repository resta dietro a quello vero, e non
/// avendo dentro niente non si fa mai vedere — se ne occupa
/// `DemoFallbackChallengeRepository`.
class SampleChallengeRepository implements ChallengeRepository {
  SampleChallengeRepository();

  final _challenges = <String, Challenge>{};
  final _entries = <String, List<ChallengeEntry>>{};
  final _votes = <String, Set<String>>{};

  /// Batte a ogni modifica. Le letture sono ricalcolate da capo a ogni battito:
  /// i dati sono una manciata di oggetti, e un aggiornamento fine qui non
  /// comprerebbe niente se non complicazione.
  final _changes = StreamController<void>.broadcast();

  void dispose() {
    _changes.close();
  }

  /// Un flusso che parte da com'e' adesso e poi segue i battiti.
  ///
  /// **Ci si iscrive ai cambiamenti prima di consegnare il valore di adesso**,
  /// e non e' pignoleria. Scritto come veniva naturale — `yield` del valore
  /// corrente e poi `yield*` dei battiti — l'iscrizione avviene un giro di
  /// eventi **dopo**, e una modifica arrivata in quel buco non la sente
  /// nessuno: i battiti sono un flusso broadcast, e quello che succede senza
  /// ascoltatori non torna piu' indietro.
  ///
  /// Si vedeva come "il voto e' scritto ma l'elenco dei voti dice ancora di
  /// no", cioe' esattamente la cosa che sul database vero non succede — e una
  /// prova in memoria che si comporta peggio del database assolve un codice che
  /// sul database sbaglierebbe.
  Stream<T> _watch<T>(T Function() read) {
    final controller = StreamController<T>();
    StreamSubscription<void>? beats;

    controller
      ..onListen = () {
        beats = _changes.stream.listen((_) => controller.add(read()));
        controller.add(read());
      }
      ..onCancel = () async {
        await beats?.cancel();
        beats = null;
      };

    return controller.stream;
  }

  void _emit() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  bool owns(String challengeId) => _challenges.containsKey(challengeId);

  @override
  Stream<List<Challenge>> watchLiveChallenges() {
    return _watch(() {
      final now = DateTime.now();
      final live =
          _challenges.values
              .where((challenge) => challenge.isLiveAt(now))
              .toList()
            ..sort((a, b) => a.endsAt.compareTo(b.endsAt));

      return live;
    });
  }

  @override
  Stream<List<Challenge>> watchEndedChallenges() {
    return _watch(() {
      final now = DateTime.now();
      // La stessa finestra delle challenge vere: due giorni e poi via. Le due
      // strade devono comportarsi allo stesso modo.
      final since = now.subtract(Challenge.winnersWindow);
      final ended =
          _challenges.values
              .where(
                (challenge) =>
                    challenge.hasEndedAt(now) &&
                    challenge.endsAt.isAfter(since),
              )
              .toList()
            ..sort((a, b) => b.endsAt.compareTo(a.endsAt));

      return ended;
    });
  }

  @override
  Stream<Challenge?> watchChallenge(String challengeId) {
    return _watch(() => _challenges[challengeId]);
  }

  @override
  Stream<List<ChallengeEntry>> watchEntries(String challengeId) {
    return _watch(() {
      final entries = [...?_entries[challengeId]]
        ..sort((a, b) => b.votes.compareTo(a.votes));

      return entries;
    });
  }

  @override
  Stream<List<ChallengeEntry>> watchEntriesByUser(String userId) {
    return _watch(() {
      final mine =
          _entries.values
              .expand((entries) => entries)
              .where((entry) => entry.userId == userId)
              .toList()
            ..sort(
              (a, b) =>
                  (b.createdAt ?? _never).compareTo(a.createdAt ?? _never),
            );

      return mine;
    });
  }

  @override
  Future<Challenge> createChallenge(Challenge challenge) async {
    // Anche le challenge lanciate senza Firebase restano riconoscibili come
    // roba di prova: il prefisso `demo-` e' quello che dice a tutto il resto
    // dell'app che questa vive in memoria.
    final created = challenge.copyWith(
      id:
          '${Challenge.demoIdPrefix}${_challenges.length + 1}-'
          '${challenge.title.hashCode.abs()}',
    );

    _add(created, const []);
    _emit();

    return created;
  }

  @override
  Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required String userId,
    required String authorName,
    required Uint8List bytes,
    MediaKind mediaKind = MediaKind.photo,
    String? contentType,
    String caption = '',
  }) async {
    final challenge = _challenges[challengeId];

    if (challenge == null) {
      throw const SampleChallengeMissingException();
    }

    final entries = _entries.putIfAbsent(challengeId, () => []);

    // Una foto sola a testa, come su Firestore. La regola vive in tutti e due i
    // repository: se valesse solo su quello vero, provando l'app sugli esempi
    // si vedrebbe un prodotto che si comporta in un altro modo.
    if (entries.any((entry) => entry.userId == userId)) {
      throw const AlreadyParticipatingException();
    }

    final entry = ChallengeEntry(
      id: userId,
      challengeId: challengeId,
      challengeTitle: challenge.title,
      userId: userId,
      authorName: authorName,
      // La foto appena scattata **si vede davvero**, anche senza Storage: i
      // byte finiscono dentro l'indirizzo stesso. E' l'unico modo per provare
      // il giro completo — scatto, invio, la mia foto in gara — con un
      // repository che vive in memoria.
      mediaUrl: _dataUri(bytes, contentType),
      mediaKind: mediaKind,
      caption: caption.trim(),
      createdAt: DateTime.now(),
    );

    entries.add(entry);
    _challenges[challengeId] = challenge.copyWith(
      participantsCount: challenge.participantsCount + 1,
    );

    _emit();

    return entry;
  }

  final _comments = <String, List<EntryComment>>{};

  static String _commentKey(String challengeId, String entryId) =>
      '${challengeId}__$entryId';

  @override
  Stream<List<EntryComment>> watchComments({
    required String challengeId,
    required String entryId,
  }) {
    return _watch(() => [...?_comments[_commentKey(challengeId, entryId)]]);
  }

  @override
  Future<EntryComment> addComment({
    required String challengeId,
    required String entryId,
    required String userId,
    required String authorName,
    required String text,
    List<EntryMention> mentions = const [],
  }) async {
    final key = _commentKey(challengeId, entryId);
    final elenco = _comments.putIfAbsent(key, () => []);

    final comment = EntryComment(
      id: '${key}__${elenco.length + 1}',
      challengeId: challengeId,
      entryId: entryId,
      userId: userId,
      authorName: authorName,
      text: text.trim(),
      mentions: mentions,
      createdAt: DateTime.now(),
    );

    elenco.add(comment);
    _emit();

    return comment;
  }

  @override
  Future<void> setVote({
    required String challengeId,
    required String entryId,
    required String userId,
    required bool voted,
  }) async {
    final votedIds = _votes.putIfAbsent(userId, () => <String>{});
    // La gara fa parte del nome del voto, come sulle challenge vere: le due
    // strade devono comportarsi allo stesso modo, altrimenti la prova in
    // memoria assolve un codice che sul database sbaglia.
    final voteKey = '${challengeId}__$entryId';

    if (votedIds.contains(voteKey) == voted) {
      return;
    }

    if (voted) {
      votedIds.add(voteKey);
    } else {
      votedIds.remove(voteKey);
    }

    final entries = _entries[challengeId];
    final index = entries?.indexWhere((entry) => entry.id == entryId) ?? -1;

    if (entries != null && index >= 0) {
      final entry = entries[index];
      final next = entry.votes + (voted ? 1 : -1);

      // Stessa regola delle challenge vere: le fiamme non vanno sotto zero.
      // Qui e' quasi impossibile arrivarci, ma le due strade devono comportarsi
      // allo stesso modo — altrimenti la prova in memoria assolve un codice che
      // sul database sbaglia.
      entries[index] = entry.copyWith(votes: next < 0 ? 0 : next);
    }

    _emit();
  }

  @override
  Future<void> proclaimWinner({
    required String challengeId,
    required String winnerEntryId,
    required String winnerUserId,
    ChallengeEntry? winner,
  }) async {
    final challenge = _challenges[challengeId];

    if (challenge == null) {
      return;
    }

    _challenges[challengeId] = challenge.copyWith(
      winnerEntryId: winnerEntryId,
      winnerUserId: winnerUserId,
      // Come nel repository vero: la foto vincente si ricopia sulla gara, e da
      // li' in poi il trofeo non dipende piu' dalla partecipazione.
      winnerUsername: winner?.authorName ?? '',
      winnerMediaUrl: winner?.mediaUrl ?? '',
      winnerMediaKind: winner?.mediaKind ?? MediaKind.photo,
      winnerVotes: winner?.votes ?? 0,
    );

    final entries = _entries[challengeId];
    final index = entries?.indexWhere((entry) => entry.id == winnerEntryId);

    if (entries != null && index != null && index >= 0) {
      entries[index] = entries[index].copyWith(isWinner: true);
    }

    _emit();
  }

  @override
  Stream<Set<String>> watchVotedEntryIds(String userId) {
    return _watch(() => {...?_votes[userId]});
  }

  @override
  Stream<List<Challenge>> watchTrophiesOf(String userId) {
    return _watch(
      () => [
        for (final challenge in _challenges.values)
          if (challenge.hasTrophy && challenge.winnerUserId == userId)
            challenge,
      ],
    );
  }

  @override
  Stream<List<Challenge>> watchCommissionedBy(String userId) {
    // Le aperte prima, i trofei dopo: la stessa regola del repository vero, e
    // per questo scritta una volta sola nel dominio. Due copie sarebbero due
    // bacheche che si comportano diversamente a seconda che Firebase sia
    // configurato o no, cioe' la differenza piu' difficile da vedere che ci
    // sia.
    return _watch(
      () => commissionedOrder([
        for (final challenge in _challenges.values)
          if (challenge.createdByUserId == userId) challenge,
      ], now: DateTime.now()),
    );
  }

  static final DateTime _never = DateTime.fromMillisecondsSinceEpoch(0);

  /// I byte di una foto trasformati in un indirizzo che li contiene.
  static String _dataUri(Uint8List bytes, String? contentType) {
    final type =
        (contentType ?? '').startsWith('image/') ||
            (contentType ?? '').startsWith('video/')
        ? contentType!
        : 'image/jpeg';

    return 'data:$type;base64,${base64Encode(bytes)}';
  }

  void _add(Challenge challenge, List<ChallengeEntry> entries) {
    _challenges[challenge.id] = challenge;
    _entries[challenge.id] = [...entries];
  }
}

/// Chiesta una challenge di esempio che non esiste.
class SampleChallengeMissingException implements Exception {
  const SampleChallengeMissingException();

  @override
  String toString() => 'SampleChallengeMissingException';
}
