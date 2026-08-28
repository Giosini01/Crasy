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
            if (challenge.isLiveAt(now) && challenge.isPayable) challenge,
        ]
        // Prima quella **che chiude prima**: e' l'unica per cui guardare adesso
        // invece che stasera cambia qualcosa.
        ..sort((a, b) => a.endsAt.compareTo(b.endsAt));

  final trophies =
      [
          for (final challenge in challenges)
            if (challenge.hasTrophy) challenge,
        ]
        // La bacheca si legge dall'ultimo trofeo: e' quello di cui ci si
        // ricorda.
        ..sort((a, b) => b.endsAt.compareTo(a.endsAt));

  return [...live, ...trophies];
}
