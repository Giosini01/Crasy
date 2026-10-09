import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/utils/combina_flussi.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/data/payments_service.dart';
import 'package:crasy/features/payments/data/wallet_repository.dart';
import 'package:crasy/features/payments/domain/entities/ledger_entry.dart';
import 'package:crasy/features/payments/domain/entities/payout_details.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/entities/wallet.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentsServiceProvider = Provider<PaymentsService>(
  (ref) => PaymentsService(ref.watch(firebaseFunctionsProvider)),
);

final walletRepositoryProvider = Provider<WalletRepository?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return WalletRepository(ref.watch(firebaseFirestoreProvider));
});

/// Quanto vale il portafoglio da mostrare, oggi.
///
/// A pagamenti accesi e' il **saldo vero**, scritto dal server: soldi incassati
/// da CRASY che aspettano solo di essere prelevati.
///
/// A pagamenti spenti e' il **totale dei premi vinti**, ricavato incrociando le
/// gare chiuse con le proprie partecipazioni. E' un numero calcolato, non un
/// numero salvato, e la differenza qui e' tutto: `walletCents` sul database
/// diventera' denaro prelevabile davvero, e **nessun telefono lo puo'
/// scrivere**. Se lo lasciassimo scrivere adesso "tanto non ci sono soldi",
/// chiunque potrebbe scriversi diecimila euro oggi e prelevarli il giorno che i
/// pagamenti si accendono.
final walletBalanceProvider = Provider<int>((ref) {
  if (paymentsEnabled) {
    return ref.watch(walletProvider).valueOrNull?.balanceCents ?? 0;
  }

  return ref.watch(myPrizeCentsProvider);
});

/// I miei dati per il prelievo, se li ho gia' messi.
///
/// Nullo vuol dire "mai compilati": e' la differenza fra chi deve ancora
/// passare dal modulo e chi lo ha gia' fatto, ed e' quella a decidere dove
/// porta il tasto "preleva".
final payoutDetailsProvider = StreamProvider<PayoutDetails?>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(null);
  }

  return repository.watchPayoutDetails(userId);
});

/// **L'estratto conto: tutti i movimenti di denaro, anche quelli fuori dal
/// portafoglio.**
final ledgerProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const <LedgerEntry>[]);
  }

  return repository.watchLedger(userId);
});

/// Il mio portafoglio: quanto c'e' dentro e da dove viene.
final walletProvider = StreamProvider<Wallet>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(const Wallet());
  }

  // Saldo e movimenti arrivano da due documenti diversi e vanno guardati
  // insieme: un saldo che cambia senza la riga che lo spiega, anche solo per
  // mezzo secondo, e' un numero che compare dal nulla.
  //
  // **Prima erano annidati con `asyncExpand`, e il saldo si fermava.** Quel
  // metodo aspetta che il flusso interno finisca prima di leggere un altro
  // valore dall'esterno, e un ascolto su Firestore non finisce mai: il saldo
  // veniva letto una volta sola, all'apertura, e restava quello.
  //
  // Si vedeva pagando una missione col portafoglio: la riga del pagamento
  // compariva nell'elenco — il flusso interno era vivo — e il numero sopra non
  // si muoveva fino alla riapertura dell'app. Da fuori non e' un difetto
  // dell'interfaccia: sono soldi spesi che non vengono scalati.
  //
  // Vedi `combinaDue`, che li ascolta davvero tutti e due.
  return combinaTre(
    repository.watchBalance(userId),
    repository.watchWithdrawing(userId),
    repository.watchMovements(userId),
    (balance, inViaggio, movements) => Wallet(
      balanceCents: balance,
      withdrawingCents: inViaggio,
      movements: movements,
    ),
  );
});
