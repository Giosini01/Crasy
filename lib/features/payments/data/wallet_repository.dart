import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/payments/domain/entities/payout_details.dart';
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

  Stream<int> watchWithdrawing(String userId) {
    return _user(userId).snapshots().map(
      (snapshot) =>
          (snapshot.data()?['withdrawingCents'] as num?)?.toInt() ?? 0,
    );
  }

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

  /// **I dati per il prelievo stanno in un documento a parte.**
  ///
  /// Non dentro il profilo, che e' fatto per essere letto: il profilo lo legge
  /// chiunque apra la pagina di una persona, e un codice fiscale in mezzo al
  /// nome e alla foto sarebbe leggibile da tutta l'app per un errore di una
  /// riga nelle regole. Qui invece sono in una stanza che si apre a una sola
  /// persona, e la regola che lo dice e' una sola riga anche lei — ma sbagliarla
  /// non basta a far uscire niente, perche' nessuna schermata li chiede.
  DocumentReference<Map<String, dynamic>> _payout(String userId) =>
      _user(userId).collection('private').doc('payout');

  Stream<PayoutDetails?> watchPayoutDetails(String userId) {
    return _payout(userId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      return PayoutDetails(
        firstName: data['firstName'] as String? ?? '',
        lastName: data['lastName'] as String? ?? '',
        fiscalCode: data['fiscalCode'] as String? ?? '',
        iban: data['iban'] as String? ?? '',
        birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      );
    });
  }

  Future<void> savePayoutDetails(String userId, PayoutDetails details) {
    return _payout(userId).set({
      'firstName': details.firstName.trim(),
      'lastName': details.lastName.trim(),
      'fiscalCode': PayoutValidators.normalize(details.fiscalCode),
      'iban': PayoutValidators.normalize(details.iban),
      if (details.birthDate case final nato?)
        'birthDate': Timestamp.fromDate(nato),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
