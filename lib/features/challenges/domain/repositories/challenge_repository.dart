import 'dart:typed_data';

import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
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

  /// Le gare **riservate** in cui compaio fra i destinatari: quelle lanciate
  /// dai miei amici solo per gli amici, e le mie.
  Stream<List<Challenge>> watchChallengesFor(String userId);

  /// **La sola foto in vetrina**: quella che sta vincendo, gia' pronta da
  /// mostrare.
  ///
  /// Esiste separata da [watchEntries] per una ragione di conto: la scheda di
  /// una gara mostra una foto sola, e leggerne trecento per prenderne una e'
  /// il modo piu' veloce di spendere il piano gratuito di Firestore. Qui
  /// l'ordine lo fa il database e ne tornano cinque.
  Stream<ChallengeEntry?> watchTopEntry(
    String challengeId, {
    bool live = false,
  });

  /// La gara scelta per la sfida del giorno, per il giorno `AAAA-MM-GG`.
  ///
  /// Torna **l'identificativo di una gara che esiste gia'**, non una gara
  /// nuova, e la differenza non e' tecnica: CRASY non mette premi in palio.
  /// Una societa' che promette un premio fa un concorso a premi, con tutto
  /// quello che comporta; qui la sfida del giorno e' una gara di qualcuno,
  /// messa in cima per un giorno. I soldi restano di chi l'ha lanciata.
  ///
  /// Nullo quando per oggi non e' stato scelto niente: in quel caso decide
  /// l'app, sempre allo stesso modo per tutti.
  Stream<String?> watchDailyPick(String day);

  /// Le challenge chiuse, dalla piu' recente. E' la sezione dei vincitori.
  Stream<List<Challenge>> watchEndedChallenges();

  /// Una challenge sola. Emette `null` se non esiste.
  Stream<Challenge?> watchChallenge(String challengeId);

  /// Le partecipazioni a una challenge, dalla piu' votata.
  Stream<List<ChallengeEntry>> watchEntries(String challengeId);

  /// Le partecipazioni di una persona, per il suo profilo.
  Stream<List<ChallengeEntry>> watchEntriesByUser(String userId);

  /// Le partecipazioni di **piu' persone insieme**, in una lettura sola.
  ///
  /// Serve alla schermata degli amici, che deve dire cosa sta facendo ognuno:
  /// chiedendo una persona per volta sarebbero venti richieste per venti
  /// amici, ogni volta che quella scheda si apre.
  Stream<List<ChallengeEntry>> watchEntriesByUsers(List<String> userIds);

  /// Lancia una challenge. Torna quella creata, con il suo identificativo.
  ///
  /// L'oggetto passato arriva senza `id` — lo assegna chi scrive.
  Future<Challenge> createChallenge(Challenge challenge);

  /// Cancella una gara a cui non ha partecipato nessuno.
  ///
  /// **Dalla prima foto in poi non si puo' piu'**, e non e' una limitazione
  /// tecnica: chi ha mandato uno scatto ha speso una delle sue partecipazioni
  /// del giorno, e cancellargliela sotto vorrebbe dire prendergliela senza
  /// dargli niente in cambio. A quel punto la gara non e' piu' solo di chi
  /// l'ha lanciata.
  ///
  /// Il controllo vero sta nelle regole del database: qui si chiede, li' si
  /// decide.
  Future<void> deleteChallenge(String challengeId);

  /// Invia una partecipazione: carica la foto e registra il documento.
  ///
  /// Prende i byte e non un percorso perche' su web `XFile.path` e' un blob url
  /// che Storage non sa leggere.
  Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required String userId,
    required String authorName,
    required Uint8List bytes,
    String? filePath,
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

  /// **La risposta a una sfida mirata**: l'ha accettata, l'ha rifiutata,
  /// oppure l'ha portata a termine.
  ///
  /// La scrive solo chi l'ha ricevuta. Non e' un dettaglio d'interfaccia: una
  /// sfida che chi l'ha lanciata puo' segnare come accettata non e' una parola
  /// data. Le regole di Firestore impongono la stessa cosa dall'altra parte.
  ///
  /// [restartAt] rimette in moto l'orologio, e serve a un caso solo: chi aveva
  /// detto di no e ci ha ripensato. Una sfida rifiutata ha smesso di contare i
  /// minuti da un pezzo — spesso e' gia' oltre la scadenza — e riaprirla senza
  /// toccare il tempo vorrebbe dire riaprirla gia' scaduta. Le regole lasciano
  /// spostarla solo in avanti e solo di poco, e solo tornando da un rifiuto.
  Future<void> answerDuel({
    required String challengeId,
    required DuelStatus status,
    DateTime? restartAt,
  });

  /// **Il giudizio di chi ha lanciato la sfida**: la foto vale, o non vale.
  ///
  /// E' l'altra meta' di [answerDuel], e sta dalla parte opposta: la scrive
  /// solo chi ha lanciato la sfida, e solo dopo che la foto e' arrivata.
  ///
  /// Serve perche' una sfida mirata ha **un partecipante solo**: il conteggio
  /// delle fiamme, che decide ogni altra gara, qui non decide niente — chiunque
  /// mandi qualcosa vince, e quel qualcosa puo' essere un video nero su una
  /// sfida che diceva "balla in mezzo alla piazza".
  ///
  /// Il giudizio **chiude la sfida nel momento in cui arriva**, e non c'e'
  /// niente da aspettare: approvata, la foto diventa il trofeo di chi l'ha
  /// fatta; bocciata, la sfida si chiude senza vincitore. In tutti e due i casi
  /// si scrive `winnerEntryId`, che e' il segno che una gara e' stata chiusa —
  /// senza, il server tornerebbe a guardarla ogni cinque minuti in eterno.
  Future<void> judgeDuel({
    required String challengeId,
    required bool approved,
    ChallengeEntry? entry,
  });

  /// Le gare riservate a [userId] **appena finite**: le ultime ventiquattro ore.
  ///
  /// E' l'altra meta' di [watchChallengesFor], che si ferma a quelle ancora
  /// aperte. Senza, una missione fra amici spariva dal party nell'istante in
  /// cui scadeva — proprio il momento in cui si vuole guardare com'e' finita e
  /// chi ha vinto. Ventiquattro ore, e poi via: quello che resta e' la figurina
  /// sul profilo di chi ha vinto, che non scade mai.
  Stream<List<Challenge>> watchRecentlyClosedFor(String userId);

  /// Le gare che [userId] ha **vinto**. La sua bacheca dei trofei.
  ///
  /// [viewerId] e' **chi sta guardando**, e cambia cosa si vede: le gare
  /// riservate compaiono solo a chi ne fa parte. Non e' una regola
  /// dell'interfaccia — e' la stessa che il database applica leggendo
  /// `audience` — ma va detta anche qui, perche' una lettura che chiede piu' di
  /// quello che si puo' avere non torna filtrata: **fallisce tutta**, e la
  /// bacheca resta vuota per chiunque non sia amico.
  /// [friend] dice se chi guarda e' **amico** di [userId]. Solo allora si
  /// chiedono anche le sfide mirate superate: le regole del database le aprono
  /// agli amici e a nessun altro, e una lettura che ne chiedesse una a cui non
  /// si ha diritto non verrebbe filtrata — verrebbe respinta tutta.
  Stream<List<Challenge>> watchTrophiesOf(
    String userId, {
    String? viewerId,
    bool friend = false,
  });

  /// Le gare che [userId] ha **commissionato** e che hanno prodotto qualcosa.
  ///
  /// Chi mette i soldi non gareggia, quindi non vincera' mai niente: senza
  /// questo, del gesto piu' impegnativo dell'app non resterebbe traccia. Qui
  /// resta la foto che ha fatto fare.
  ///
  /// [viewerId] vale come per [watchTrophiesOf]: chi non e' amico di [userId]
  /// vede le sue gare pubbliche e nient'altro — le missioni lanciate al gruppo
  /// restano dentro il gruppo.
  Stream<List<Challenge>> watchCommissionedBy(String userId, {String? viewerId});
}
