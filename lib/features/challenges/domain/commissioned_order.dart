import 'package:crasy/features/challenges/domain/entities/challenge.dart';

/// Le gare lanciate da una persona, nell'ordine in cui vanno guardate.
///
/// **Prima quelle ancora aperte, poi i trofei.** Una gara in corso e' l'unica
/// cosa di questa bacheca su cui si possa ancora fare qualcosa — entrarci,
/// partecipare, vedere a che punto e' — mentre un trofeo e' finito e resta li'.
/// Mescolarli in un ordine solo, per data, seppellirebbe la gara di stamattina
/// sotto quella vinta ieri.
///
/// **Prima da qui usciva soltanto cio' che aveva prodotto un trofeo.** Chi
/// lanciava una challenge la mattina non ne trovava traccia da nessuna parte
/// fino a gara chiusa: ne' sul proprio profilo ne' su quello che gli altri
/// guardano. Il gesto piu' impegnativo dell'app — tirare fuori dei soldi e
/// dettare una consegna — era invisibile proprio nelle ore in cui contava.
///
/// Sta nel dominio e non dentro un repository perche' i repository sono due —
/// quello di Firestore e quello delle challenge di esempio — e due copie della
/// stessa regola sono due regole che prima o poi si dicono cose diverse.
List<Challenge> commissionedOrder(
  List<Challenge> challenges, {
  required DateTime now,
}) {
  final live =
      [
          for (final challenge in challenges)
            // `isPayable` vale anche qui: acceso l'interruttore dei pagamenti,
            // una gara non pagata non si vede da nessuna parte, nemmeno sul
            // profilo di chi l'ha scritta. Sulle gare gia' concluse non si
            // applica, per non far sparire trofei che oggi si vedono.
            //
            // **E che non sia gia' stata chiusa**, che sembra ovvio e per anni
            // lo e' stato: una gara normale il vincitore ce l'ha solo dopo la
            // sirena, quindi "aperta" e "ha un trofeo" non potevano essere vere
            // insieme. Una sfida mirata si chiude nell'istante in cui chi
            // l'ha lanciata dice che vale — spesso ore prima della scadenza —
            // e da quel momento era **tutte e due le cose**: finiva nell'elenco
            // delle aperte e in quello dei trofei, e la stessa figurina
            // compariva due volte di fila sul profilo di chi l'aveva lanciata.
            if (challenge.isLiveAt(now) &&
                challenge.winnerEntryId == null &&
                challenge.isPayable)
              challenge,
        ]
        // Prima quella **che chiude prima**: e' l'unica per cui guardare adesso
        // invece che stasera cambia qualcosa.
        ..sort((a, b) => a.endsAt.compareTo(b.endsAt));

  final finite =
      [
          for (final challenge in challenges)
            // **Finite, non "che hanno lasciato una foto".**
            //
            // Prima passavano solo quelle con un trofeo — vincitore piu'
            // immagine — perche' questa bacheca era fatta di figurine, e una
            // cornice con dentro il vuoto si legge come un'immagine che non si
            // e' caricata. Il risultato era che una gara lanciata, finita senza
            // che partecipasse nessuno, **spariva dal profilo di chi l'aveva
            // lanciata** pur restando visibile fra i vincitori: una cosa che
            // hai fatto e che non c'e' piu' da nessuna parte.
            //
            // Adesso qui ci sono targhe, e una targa non ha bisogno di nessuna
            // foto: puo' dire benissimo "nessun vincitore". La ragione di
            // escluderle e' caduta insieme alle figurine.
            // **O finita, o gia' chiusa.** Le due cose non coincidono: una
            // sfida mirata si chiude nell'istante del verdetto, che puo'
            // arrivare ore prima della scadenza. Guardare solo l'orologio la
            // farebbe sparire da tutte e due gli elenchi — fuori dalle aperte
            // perche' ha gia' un vincitore, fuori da qui perche' l'ora non e'
            // ancora arrivata.
            if (challenge.hasEndedAt(now) || challenge.winnerEntryId != null)
              challenge,
        ]
        // La bacheca si legge dall'ultimo trofeo: e' quello di cui ci si
        // ricorda.
        ..sort((a, b) => b.endsAt.compareTo(a.endsAt));

  return [...live, ...finite];
}
