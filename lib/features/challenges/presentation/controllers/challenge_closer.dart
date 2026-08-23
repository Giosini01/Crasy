import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final challengeCloserProvider = Provider<ChallengeCloser>(ChallengeCloser.new);

/// Chiude una gara a cui **nessuno ha assegnato il premio in tempo**.
///
/// **Questo lavoro e' del server, e il codice del server c'e' gia'**: la
/// funzione che gira ogni cinque minuti sta in `functions/index.js` e richiede
/// il piano a pagamento di Firebase. Finche' quel piano non e' attivo, nessuna
/// challenge si chiude: scadono e restano li' per sempre, senza vincitore. Il
/// giro del prodotto — si lancia, si partecipa, si vota, **qualcuno vince** —
/// non si vede mai finire, che per un'app in prova e' come non averlo.
///
/// Cosi' la chiude il primo che la apre dopo la scadenza. La classifica la
/// calcola qui, con le stesse regole del server: piu' fiamme per prima, a
/// parita' chi ha mandato prima, e fuori dalla gara chi non ha passato il
/// controllo.
///
/// **Questa e' la strada di riserva, non quella principale.** Il vincitore lo
/// sceglie chi ha lanciato la gara, e ha ventiquattro ore per farlo: qui si
/// arriva solo quando quelle ore passano senza che nessuno abbia deciso. Una
/// gara che resta senza vincitore perche' chi l'ha lanciata si e' distratto e'
/// la cosa che fa perdere fiducia a tutti gli altri — e il premio, a quel
/// punto, va a chi ha preso piu' fiamme.
///
/// Il permesso, nelle regole di Firestore, e' legato a una condizione che **si
/// spegne da sola**: vale solo se il premio non e' stato incassato da CRASY. Il
/// giorno in cui i pagamenti si accendono, ogni gara visibile ha i soldi in
/// cassa e da qui non si proclama piu' niente — senza che nessuno debba
/// ricordarsi di togliere questa strada.
class ChallengeCloser {
  ChallengeCloser(this._ref);

  final Ref _ref;

  /// Le gare gia' chiuse in questa sessione.
  ///
  /// La schermata si ricostruisce a ogni fiamma che qualcuno accende, e senza
  /// questo insieme il tentativo ripartirebbe a ogni ricostruzione: decine di
  /// scritture rifiutate per una gara che e' gia' stata chiusa un secondo fa.
  final Set<String> _done = {};

  /// Chiude [challenge] se e' ora. Non fa niente e non lancia in tutti gli
  /// altri casi: chi la chiama e' una schermata che si sta disegnando.
  ///
  /// [entriesLoaded] dice se l'elenco delle partecipazioni **e' davvero
  /// arrivato**, e non e' un dettaglio: e' il bug che ha proclamato "non ha
  /// partecipato nessuno" su una gara che aveva un partecipante con due
  /// fiamme. La schermata si disegna prima che lo stream emetta, e in quel
  /// primo istante l'elenco e' vuoto — non perche' non ci sia nessuno, ma
  /// perche' non e' ancora arrivato niente. Chiudere li' vuol dire scrivere
  /// "nessun vincitore" per sempre, su una gara che un vincitore ce l'aveva.
  ///
  /// Una lista vuota **caricata** e una lista vuota **non ancora caricata** si
  /// somigliano al punto da essere lo stesso oggetto, e qui la differenza vale
  /// un premio.
  Future<void> closeIfNeeded(
    Challenge challenge,
    List<ChallengeEntry> entries, {
    required bool entriesLoaded,
  }) async {
    if (!entriesLoaded || !_shouldClose(challenge)) {
      return;
    }

    _done.add(challenge.id);

    final winner = _winnerOf(entries);

    try {
      await _ref
          .read(challengeRepositoryProvider)
          .proclaimWinner(
            challengeId: challenge.id,
            // Vuoto vuol dire "non ha partecipato nessuno". Si scrive lo
            // stesso: senza, questa gara verrebbe ricontrollata per sempre.
            winnerEntryId: winner?.id ?? '',
            winnerUserId: winner?.userId ?? '',
          );
    } on Exception catch (_) {
      // Il caso normale e' che qualcun altro l'abbia chiusa un istante prima.
      // Non c'e' niente da dire a nessuno: la gara e' chiusa, che e' quello che
      // si voleva.
    }
  }

  bool _shouldClose(Challenge challenge) {
    // Le challenge di esempio non hanno bisogno di un'eccezione: vivono in
    // memoria, e il repository che le ospita risponde a `proclaimWinner` come
    // farebbe quello vero. Una gara di prova che si chiude e proclama e' anzi
    // il modo piu' onesto di far vedere come funziona.
    if (_done.contains(challenge.id)) {
      return false;
    }

    // Gia' proclamata: la stringa vuota conta come proclamata, e vuol dire
    // "nessun partecipante".
    if (challenge.winnerEntryId != null) {
      return false;
    }

    // **Non basta che la gara sia finita: deve essere scaduto anche il tempo
    // per scegliere.**
    //
    // A decidere chi vince e' chi ha lanciato la gara, e ha ventiquattro ore
    // per farlo. Chiudere prima vorrebbe dire togliergli il verdetto di mano e
    // darlo al conteggio delle fiamme — cioe' esattamente la cosa che non deve
    // succedere finche' quelle ore non sono passate.
    if (!challenge.choiceExpiredAt(DateTime.now())) {
      return false;
    }

    // **Con dei soldi in cassa non si tocca.** E' la stessa condizione scritta
    // nelle regole del database, ripetuta qui per non fare un tentativo che
    // verrebbe rifiutato.
    return challenge.prizeStatus == PrizeStatus.unpaid;
  }

  /// Chi ha vinto: piu' fiamme, e a parita' chi ha mandato prima.
  ///
  /// Serve una regola qualunque per il pareggio, ma serve che sia **sempre la
  /// stessa**: con dei soldi in mezzo, un pareggio risolto a caso e' una lite.
  ChallengeEntry? _winnerOf(List<ChallengeEntry> entries) {
    final eligible = entries
        .where((entry) => entry.moderation != EntryModeration.rejected)
        .toList();

    if (eligible.isEmpty) {
      return null;
    }

    eligible.sort((a, b) {
      final byVotes = b.votes.compareTo(a.votes);

      if (byVotes != 0) {
        return byVotes;
      }

      final at = a.createdAt;
      final bt = b.createdAt;

      if (at == null || bt == null) {
        return 0;
      }

      return at.compareTo(bt);
    });

    return eligible.first;
  }
}
