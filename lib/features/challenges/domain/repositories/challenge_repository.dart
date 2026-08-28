import 'dart:typed_data';

import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';

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
    MediaKind mediaKind = MediaKind.photo,
    String? contentType,
    String caption = '',
  });

  /// I commenti sotto una foto, dal piu' vecchio.
  ///
  /// Dal piu' vecchio e non dal piu' recente: sotto una foto si legge una
  /// conversazione, e una conversazione si legge nell'ordine in cui e'
  /// avvenuta. E' il contrario dei trofei, dove conta l'ultimo.
  Stream<List<EntryComment>> watchComments({
    required String challengeId,
    required String entryId,
  });

  /// Scrive un commento. Torna quello scritto, cosi' chi chiama sa com'e'
  /// venuto senza aspettare il giro del flusso.
  Future<EntryComment> addComment({
    required String challengeId,
    required String entryId,
    required String userId,
    required String authorName,
    required String text,
    List<EntryMention> mentions = const [],
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

  /// Proclama chi ha vinto una gara gia' scaduta.
  ///
  /// **Questo lo dovrebbe fare il server, e lo fara'.** La funzione che gira
  /// ogni cinque minuti e chiude le gare scadute e' scritta
  /// (`functions/index.js`), e richiede il piano a pagamento di Firebase. Fino
  /// ad allora nessuna challenge si chiuderebbe mai: scadono e restano li',
  /// senza vincitore, e il giro del prodotto non si vede finire.
  ///
  /// Cosi' lo chiude il primo che apre la gara dopo la scadenza. Il permesso e'
  /// legato a una condizione che si spegne da sola: **vale solo se il premio
  /// non e' stato incassato da CRASY**. Il giorno in cui i pagamenti si
  /// accendono, ogni gara visibile ha i soldi in cassa e nessun telefono puo'
  /// piu' proclamare niente — senza che qualcuno debba ricordarsi di togliere
  /// questa strada.
  ///
  /// [winnerEntryId] vuoto vuol dire "nessuno ha partecipato": si scrive lo
  /// stesso, per non ricontrollare la stessa gara per sempre.
  /// [winner] e' la partecipazione che ha vinto, quando c'e'. Serve a
  /// ricopiare la foto dentro la gara — il trofeo sopravvive alla pulizia che
  /// quarantotto ore dopo cancella le partecipazioni.
  Future<void> proclaimWinner({
    required String challengeId,
    required String winnerEntryId,
    required String winnerUserId,
    ChallengeEntry? winner,
  });

  /// Le gare che [userId] ha **vinto**. La sua bacheca dei trofei.
  Stream<List<Challenge>> watchTrophiesOf(String userId);

  /// Le gare che [userId] ha **commissionato** e che hanno prodotto qualcosa.
  ///
  /// Chi mette i soldi non gareggia, quindi non vincera' mai niente: senza
  /// questo, del gesto piu' impegnativo dell'app non resterebbe traccia. Qui
  /// resta la foto che ha fatto fare.
  Stream<List<Challenge>> watchCommissionedBy(String userId);
}
