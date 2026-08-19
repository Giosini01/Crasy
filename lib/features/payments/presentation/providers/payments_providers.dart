import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/data/payments_service.dart';
import 'package:crasy/features/payments/data/wallet_repository.dart';
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
  return repository.watchBalance(userId).asyncExpand((balance) {
    return repository
        .watchMovements(userId)
        .map(
          (movements) => Wallet(balanceCents: balance, movements: movements),
        );
  });
});
