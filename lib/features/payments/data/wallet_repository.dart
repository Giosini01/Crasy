import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/payments/domain/entities/wallet.dart';

/// Il portafoglio su Firestore.
///
///     users/{userId}.walletCents        il saldo
///     users/{userId}/wallet/{id}        da dove viene, riga per riga
///
/// **Da qui si legge e basta.** Il saldo lo muove solo il server: lo accredita
/// quando una gara si chiude e lo azzera quando qualcuno preleva. Le regole di
/// Firestore non permettono a nessun telefono di scriverlo, ed e' l'unica cosa
/// che impedisce a chiunque di regalarsi mille euro cambiando un numero.
///
/// I movimenti stanno accanto al saldo e non al posto suo. Sarebbe piu' pulito
/// calcolare il saldo sommandoli — un totale che non puo' andare fuori sincrono
/// — ma vorrebbe dire leggere tutta la storia di una persona ogni volta che
/// apre il profilo. Il totale sta scritto, la storia si legge solo se la si
/// guarda.
class WalletRepository {
  WalletRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String userId) =>
      _firestore.collection('users').doc(userId);

  Stream<int> watchBalance(String userId) {
    return _user(userId).snapshots().map(
      (snapshot) => (snapshot.data()?['walletCents'] as num?)?.toInt() ?? 0,
    );
  }

  Stream<List<WalletMovement>> watchMovements(String userId) {
    return _user(userId).collection('wallet').limit(50).snapshots().map((
      snapshot,
    ) {
      final movements = [
        for (final document in snapshot.docs)
          WalletMovement(
            id: document.id,
            amountCents: (document.data()['amountCents'] as num?)?.toInt() ?? 0,
            challengeTitle: document.data()['challengeTitle'] as String? ?? '',
            createdAt: (document.data()['createdAt'] as Timestamp?)?.toDate(),
          ),
      ];

      // In memoria, come ovunque nell'app: una query ordinata salta i documenti
      // a cui il server non ha ancora scritto l'ora, e un premio appena vinto
      // sparirebbe dall'elenco proprio nel momento in cui lo si va a cercare.
      movements.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;

        if (at == null && bt == null) {
          return 0;
        }

        if (at == null) {
          return -1;
        }

        if (bt == null) {
          return 1;
        }

        return bt.compareTo(at);
      });

      return movements;
    });
  }
}
