import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/data/payments_service.dart';
import 'package:crasy/features/payments/data/wallet_repository.dart';
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
