import 'dart:async';
import 'dart:typed_data';

import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';

/// Le challenge di esempio, tenute in memoria.
///
/// Servono a una cosa sola: **far vedere l'app quando il database e' vuoto**.
/// Un prodotto che gira attorno alle challenge, aperto su una schermata bianca
/// con scritto "nessuna challenge", non si capisce — non si capisce nemmeno che
/// cos'e'.
///
/// Non e' un finto repository da buttare: partecipare e votare qui funzionano
/// davvero, restano in memoria per tutta la sessione e spariscono alla
/// chiusura. Le challenge vere, quando arrivano su Firestore, prendono
/// silenziosamente il posto di queste — se ne occupa
/// `DemoFallbackChallengeRepository`.
class SampleChallengeRepository implements ChallengeRepository {
  SampleChallengeRepository({DateTime? now}) {
    _seed(now ?? DateTime.now());
  }

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

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
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
      final ended =
          _challenges.values
              .where((challenge) => challenge.hasEndedAt(now))
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
  Stream<List<ChallengeEntry>> watchLatestEntries({int limit = 30}) {
    return _watch(() {
      final all = _entries.values.expand((entries) => entries).toList()
        ..sort(
          (a, b) => (b.createdAt ?? _never).compareTo(a.createdAt ?? _never),
        );

      return all.take(limit).toList();
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
  Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required String userId,
    required String authorName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final challenge = _challenges[challengeId];

    if (challenge == null) {
      throw const SampleChallengeMissingException();
    }

    final entries = _entries.putIfAbsent(challengeId, () => []);
    final existingIndex = entries.indexWhere((entry) => entry.userId == userId);
    final entry = ChallengeEntry(
      id: userId,
      challengeId: challengeId,
      challengeTitle: challenge.title,
      userId: userId,
      authorName: authorName,
      // Le foto di esempio non hanno un indirizzo: restano in memoria per la
      // sessione, e l'interfaccia mostra il riquadro con il nome di chi ha
      // partecipato. Caricarle davvero vorrebbe dire avere Storage, cioe'
      // esattamente cio' che qui manca.
      mediaUrl: '',
      createdAt: DateTime.now(),
      votes: existingIndex >= 0 ? entries[existingIndex].votes : 0,
    );

    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
      _challenges[challengeId] = challenge.copyWith(
        participantsCount: challenge.participantsCount + 1,
      );
    }

    _emit();

    return entry;
  }

  @override
  Future<void> setVote({
    required String challengeId,
    required String entryId,
    required String userId,
    required bool voted,
  }) async {
    final votedIds = _votes.putIfAbsent(userId, () => <String>{});

    if (votedIds.contains(entryId) == voted) {
      return;
    }

    if (voted) {
      votedIds.add(entryId);
    } else {
      votedIds.remove(entryId);
    }

    final entries = _entries[challengeId];
    final index = entries?.indexWhere((entry) => entry.id == entryId) ?? -1;

    if (entries != null && index >= 0) {
      final entry = entries[index];
      entries[index] = entry.copyWith(votes: entry.votes + (voted ? 1 : -1));
    }

    _emit();
  }

  @override
  Stream<Set<String>> watchVotedEntryIds(String userId) {
    return _watch(() => {...?_votes[userId]});
  }

  static final DateTime _never = DateTime.fromMillisecondsSinceEpoch(0);

  void _add(Challenge challenge, List<ChallengeEntry> entries) {
    _challenges[challenge.id] = challenge;
    // La lista si copia: quelle del seme sono `const`, e partecipare a una
    // challenge che nasce senza foto proverebbe ad aggiungere un elemento a una
    // lista immutabile.
    _entries[challenge.id] = [...entries];
  }

  /// Le quattro challenge di esempio.
  ///
  /// Sono scelte per mostrare i quattro casi che l'interfaccia deve saper
  /// reggere: un premio grosso globale, uno nazionale, uno locale, e una
  /// challenge gia' chiusa con il suo vincitore. Le scadenze sono relative
  /// all'avvio, cosi' il countdown si muove davvero.
  void _seed(DateTime now) {
    _add(
      Challenge(
        id: '${Challenge.demoIdPrefix}global-500',
        title: 'Do something crazy',
        brief:
            'Fai la foto piu\' pazza che riesci. Senza Photoshop, senza filtri, '
            'senza scuse.',
        rules: const [
          'Una sola foto a testa.',
          'Niente fotoritocco: la foto deve uscire cosi\' dalla fotocamera.',
          'Deve essere tua e scattata durante la challenge.',
          'Vince la foto con piu\' voti allo scadere del tempo.',
        ],
        prizeCents: 50000,
        scope: ChallengeScope.global,
        startsAt: now.subtract(const Duration(hours: 18)),
        endsAt: now.add(const Duration(hours: 5, minutes: 32)),
        participantsCount: 243,
      ),
      [
        ChallengeEntry(
          id: 'demo-user-1',
          challengeId: '${Challenge.demoIdPrefix}global-500',
          challengeTitle: 'Do something crazy',
          userId: 'demo-user-1',
          authorName: 'martina',
          mediaUrl: '',
          createdAt: now.subtract(const Duration(hours: 3)),
          votes: 128,
        ),
        ChallengeEntry(
          id: 'demo-user-2',
          challengeId: '${Challenge.demoIdPrefix}global-500',
          challengeTitle: 'Do something crazy',
          userId: 'demo-user-2',
          authorName: 'leo',
          mediaUrl: '',
          createdAt: now.subtract(const Duration(hours: 6)),
          votes: 91,
        ),
      ],
    );

    _add(
      Challenge(
        id: '${Challenge.demoIdPrefix}italia-200',
        title: 'Cucina creativa',
        brief:
            'Realizza la foto piu\' creativa usando un oggetto che hai in '
            'cucina. Uno solo.',
        rules: const [
          'Un solo oggetto, e deve venire dalla tua cucina.',
          'Una foto a testa.',
          'Vince la piu\' votata.',
        ],
        prizeCents: 20000,
        scope: ChallengeScope.country,
        startsAt: now.subtract(const Duration(days: 1)),
        endsAt: now.add(const Duration(days: 2, hours: 4)),
        participantsCount: 87,
      ),
      [
        ChallengeEntry(
          id: 'demo-user-3',
          challengeId: '${Challenge.demoIdPrefix}italia-200',
          challengeTitle: 'Cucina creativa',
          userId: 'demo-user-3',
          authorName: 'giulia',
          mediaUrl: '',
          createdAt: now.subtract(const Duration(hours: 9)),
          votes: 44,
        ),
      ],
    );

    _add(
      Challenge(
        id: '${Challenge.demoIdPrefix}napoli-100',
        title: 'Lungomare',
        brief: 'Scatta la foto piu\' originale sul lungomare di Napoli.',
        rules: const [
          'La foto va scattata sul lungomare.',
          'Una foto a testa.',
          'Vince la piu\' votata.',
        ],
        prizeCents: 10000,
        scope: ChallengeScope.local,
        place: 'NAPOLI',
        startsAt: now.subtract(const Duration(hours: 4)),
        endsAt: now.add(const Duration(minutes: 47)),
        participantsCount: 31,
      ),
      const [],
    );

    final closedId = '${Challenge.demoIdPrefix}global-300-chiusa';
    _add(
      Challenge(
        id: closedId,
        title: 'Salto nel vuoto',
        brief: 'La foto piu\' assurda a mezz\'aria.',
        prizeCents: 30000,
        scope: ChallengeScope.global,
        startsAt: now.subtract(const Duration(days: 4)),
        endsAt: now.subtract(const Duration(days: 1)),
        participantsCount: 412,
        winnerEntryId: 'demo-user-4',
      ),
      [
        ChallengeEntry(
          id: 'demo-user-4',
          challengeId: closedId,
          challengeTitle: 'Salto nel vuoto',
          userId: 'demo-user-4',
          authorName: 'sara',
          mediaUrl: '',
          createdAt: now.subtract(const Duration(days: 2)),
          votes: 389,
          isWinner: true,
        ),
      ],
    );
  }
}

/// Chiesta una challenge di esempio che non esiste.
class SampleChallengeMissingException implements Exception {
  const SampleChallengeMissingException();

  @override
  String toString() => 'SampleChallengeMissingException';
}
