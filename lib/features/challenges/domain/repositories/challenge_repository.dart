import 'dart:typed_data';

import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';

/// L'unico punto da cui l'app prende e scrive le challenge.
///
/// Tutto quello che serve al giro completo — vedere le challenge, aprirne una,
/// partecipare, guardare gli altri, votare, sapere chi ha vinto — sta in questi
/// sette metodi. Se per aggiungere una schermata serve un ottavo metodo, quella
/// schermata probabilmente non fa parte dell'MVP.
abstract class ChallengeRepository {
  /// Le challenge aperte, dalla piu' vicina alla scadenza.
  Stream<List<Challenge>> watchLiveChallenges();

  /// Le challenge chiuse, dalla piu' recente. E' la sezione dei vincitori.
  Stream<List<Challenge>> watchEndedChallenges();

  /// Una challenge sola. Emette `null` se non esiste.
  Stream<Challenge?> watchChallenge(String challengeId);

  /// Le partecipazioni a una challenge, dalla piu' votata.
  Stream<List<ChallengeEntry>> watchEntries(String challengeId);

  /// Le partecipazioni piu' recenti a qualunque challenge: e' il feed.
  Stream<List<ChallengeEntry>> watchLatestEntries({int limit});

  /// Le partecipazioni di una persona, per il suo profilo.
  Stream<List<ChallengeEntry>> watchEntriesByUser(String userId);

  /// Lancia una challenge. Torna quella creata, con il suo identificativo.
  ///
  /// L'oggetto passato arriva senza `id` — lo assegna chi scrive.
  Future<Challenge> createChallenge(Challenge challenge);

  /// Invia una partecipazione: carica la foto e registra il documento.
  ///
  /// Prende i byte e non un percorso perche' su web `XFile.path` e' un blob url
  /// che Storage non sa leggere.
  Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required String userId,
    required String authorName,
    required Uint8List bytes,
    String? contentType,
  });

  /// Mette o toglie il voto. [voted] e' lo stato **desiderato**, non quello
  /// attuale: cosi' chi chiama non deve rileggere prima di scrivere.
  Future<void> setVote({
    required String challengeId,
    required String entryId,
    required String userId,
    required bool voted,
  });

  /// Gli identificativi delle partecipazioni gia' votate da [userId].
  ///
  /// Arriva come insieme e non come elenco di documenti perche' l'unica cosa
  /// che l'interfaccia deve sapere e' se il cuore di quella foto e' pieno.
  Stream<Set<String>> watchVotedEntryIds(String userId);
}
