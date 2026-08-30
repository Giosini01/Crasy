import 'dart:async';
import 'dart:typed_data';

import 'package:crasy/features/challenges/data/repositories/sample_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
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
  Stream<String?> watchDailyPick(String day) => _remote.watchDailyPick(day);

  @override
  Stream<List<Challenge>> watchLiveChallenges() {
    return _insieme(
      _remote.watchLiveChallenges(),
      _samples.watchLiveChallenges(),
      _sceltaAppiccicosa(),
    );
  }

  @override
  Stream<List<Challenge>> watchEndedChallenges() {
    return _insieme(
      _remote.watchEndedChallenges(),
      _samples.watchEndedChallenges(),
      _sceltaAppiccicosa(),
    );
  }

  /// Le gare vere se ce ne sono, quelle di esempio finche' non ne arrivano —
  /// e **una volta arrivate, non si torna piu' indietro**.
  ///
  /// ## Il difetto che questo chiude
  ///
  /// Le liste con una data dentro si rifanno ogni pochi secondi, e rifarle vuol
  /// dire riaprire l'ascolto su Firestore. La prima risposta di un ascolto
  /// appena aperto puo' essere vuota per un istante — e in quell'istante,
  /// senza questa regola, si scivolava sulle gare di esempio: tre righe al
  /// posto di dieci.
  ///
  /// Chi stava scorrendo se lo sentiva sotto il dito. La lista si accorciava,
  /// la posizione veniva riportata dentro quello che restava — cioe' in cima —
  /// e un decimo di secondo dopo tornavano le dieci righe, con lo scorrimento
  /// gia' azzerato. Scorrendo piano non si notava; scorrendo veloce si era
  /// sempre lontani dall'inizio, quindi il salto era di mezza schermata.
  ///
  /// **Il ripiego serve a chi apre l'app la prima volta**, non a coprire il
  /// respiro di un ascolto che si riapre. Una volta viste delle gare vere, di
  /// esempi non se ne parla piu'.
  List<Challenge> Function(List<Challenge>, List<Challenge>)
  _sceltaAppiccicosa() {
    var arrivateDavvero = false;

    return (remote, demo) {
      if (remote.isNotEmpty) {
        arrivateDavvero = true;

        return remote;
      }

      return arrivateDavvero ? remote : demo;
    };
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
    return _insieme(
      _remote.watchEntriesByUser(userId),
      _samples.watchEntriesByUser(userId),
      (remote, demo) => [...remote, ...demo],
    );
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
    String caption = '',
  }) {
    return _forChallenge(challengeId).submitEntry(
      challengeId: challengeId,
      userId: userId,
      authorName: authorName,
      bytes: bytes,
      mediaKind: mediaKind,
      contentType: contentType,
      caption: caption,
    );
  }

  @override
  Stream<List<EntryComment>> watchComments({
    required String challengeId,
    required String entryId,
  }) {
    return _forChallenge(
      challengeId,
    ).watchComments(challengeId: challengeId, entryId: entryId);
  }

  @override
  Future<EntryComment> addComment({
    required String challengeId,
    required String entryId,
    required String userId,
    required String authorName,
    required String text,
    List<EntryMention> mentions = const [],
  }) {
    return _forChallenge(challengeId).addComment(
      challengeId: challengeId,
      entryId: entryId,
      userId: userId,
      authorName: authorName,
      text: text,
      mentions: mentions,
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
    ChallengeEntry? winner,
  }) {
    return _forChallenge(challengeId).proclaimWinner(
      challengeId: challengeId,
      winnerEntryId: winnerEntryId,
      winnerUserId: winnerUserId,
      winner: winner,
    );
  }

  @override
  Future<void> deleteChallenge(String challengeId) =>
      _forChallenge(challengeId).deleteChallenge(challengeId);

  @override
  Stream<List<Challenge>> watchTrophiesOf(String userId) {
    return _unione(
      _remote.watchTrophiesOf(userId),
      _samples.watchTrophiesOf(userId),
    );
  }

  @override
  Stream<List<Challenge>> watchCommissionedBy(String userId) {
    return _unione(
      _remote.watchCommissionedBy(userId),
      _samples.watchCommissionedBy(userId),
    );
  }

  /// Le gare vere e quelle di esempio in un'unica bacheca, dalla piu' recente.
  ///
  /// Una gara di prova vinta e' un trofeo a tutti gli effetti: e' il modo in cui
  /// chi apre l'app per la prima volta vede com'e' fatta questa sezione, invece
  /// di trovarla vuota e non capire a cosa serva.
  Stream<List<Challenge>> _unione(
    Stream<List<Challenge>> vere,
    Stream<List<Challenge>> esempi,
  ) {
    return _insieme(
      vere,
      esempi,
      (remote, demo) =>
          [...remote, ...demo]..sort((a, b) => b.endsAt.compareTo(a.endsAt)),
    );
  }

  @override
  Stream<List<ChallengeEntry>> watchEntriesByUsers(List<String> userIds) {
    return _insieme(
      _remote.watchEntriesByUsers(userIds),
      _samples.watchEntriesByUsers(userIds),
      (remote, demo) => [...remote, ...demo],
    );
  }

  @override
  Stream<Set<String>> watchVotedEntryIds(String userId) {
    // I voti dati alle challenge vere e a quelle di esempio convivono: sono
    // insiemi di identificativi che non si sovrappongono mai, e all'interfaccia
    // serve un solo insieme per sapere quali cuori accendere.
    return _insieme(
      _remote.watchVotedEntryIds(userId),
      _samples.watchVotedEntryIds(userId),
      (remote, demo) => {...remote, ...demo},
    );
  }

  /// Tiene insieme due flussi, e **rimane in ascolto di tutti e due**.
  ///
  /// ## Il difetto che questo sostituisce
  ///
  /// Prima queste unioni erano scritte con `asyncExpand`: per ogni novita' che
  /// arrivava da Firestore si apriva il flusso degli esempi. Sembra la cosa
  /// giusta e non lo e', per un motivo che non si vede leggendo:
  /// **`asyncExpand` mette in pausa la sorgente finche' il flusso interno non
  /// finisce** — e quello degli esempi non finisce mai, perche' e' un ascolto
  /// permanente.
  ///
  /// Il risultato: **Firestore veniva ascoltato una volta sola.** La prima
  /// risposta arrivava, e da quel momento in poi tutte le altre restavano in
  /// coda per sempre. Una gara che finiva mentre l'app era aperta non compariva
  /// fra i vincitori; una foto mandata da un altro non appariva; una fiamma
  /// data altrove non si aggiornava. Sembravano tre difetti diversi, ed era
  /// una riga sola.
  ///
  /// Qui invece i due flussi si ascoltano **in parallelo** e si emette a ogni
  /// novita' dell'uno o dell'altro, tenendo l'ultimo valore di ciascuno. Il
  /// primo risultato esce quando tutti e due hanno parlato almeno una volta:
  /// emettere prima vorrebbe dire mostrare meta' dei dati e poi correggersi,
  /// che a schermo si vede come un salto.
  Stream<R> _insieme<A, B, R>(
    Stream<A> primo,
    Stream<B> secondo,
    R Function(A, B) unisci,
  ) {
    late StreamController<R> uscita;
    StreamSubscription<A>? ascoltoPrimo;
    StreamSubscription<B>? ascoltoSecondo;

    late A ultimoPrimo;
    late B ultimoSecondo;
    var hoIlPrimo = false;
    var hoIlSecondo = false;

    void manda() {
      if (hoIlPrimo && hoIlSecondo) {
        uscita.add(unisci(ultimoPrimo, ultimoSecondo));
      }
    }

    uscita = StreamController<R>(
      onListen: () {
        ascoltoPrimo = primo.listen((valore) {
          ultimoPrimo = valore;
          hoIlPrimo = true;
          manda();
        }, onError: uscita.addError);
        ascoltoSecondo = secondo.listen((valore) {
          ultimoSecondo = valore;
          hoIlSecondo = true;
          manda();
        }, onError: uscita.addError);
      },
      onCancel: () async {
        await ascoltoPrimo?.cancel();
        await ascoltoSecondo?.cancel();
      },
    );

    return uscita.stream;
  }
}
