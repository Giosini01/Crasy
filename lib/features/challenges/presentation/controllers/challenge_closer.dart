import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final challengeCloserProvider = Provider<ChallengeCloser>(ChallengeCloser.new);

/// Chiude una gara scaduta e proclama chi ha vinto.
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
  Future<void> closeIfNeeded(
    Challenge challenge,
    List<ChallengeEntry> entries,
  ) async {
    if (!_shouldClose(challenge)) {
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
    if (challenge.isDemo || _done.contains(challenge.id)) {
      return false;
    }

    // Gia' proclamata: la stringa vuota conta come proclamata, e vuol dire
    // "nessun partecipante".
    if (challenge.winnerEntryId != null) {
      return false;
    }

    if (!challenge.hasEndedAt(DateTime.now())) {
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
