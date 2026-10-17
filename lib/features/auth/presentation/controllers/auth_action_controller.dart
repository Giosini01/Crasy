import 'package:crasy/features/auth/domain/repositories/auth_repository.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authActionControllerProvider =
    AsyncNotifierProvider<AuthActionController, void>(AuthActionController.new);

class AuthActionController extends AsyncNotifier<void> {
  late final AuthRepository _authRepository;

  @override
  void build() {
    _authRepository = ref.watch(authRepositoryProvider);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => _authRepository.signIn(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => _authRepository.signUp(email: email, password: password),
    );
  }

  /// Butta l'account non confermato e torna all'ingresso.
  Future<void> discardUnverified() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(_authRepository.discardUnverifiedAccount);
  }

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      await _staccaIlTelefono();
      await _authRepository.signOut();
    });
  }

  /// **Il telefono esce dal registro prima dell'account, non dopo.**
  ///
  /// Lo toglieva gia' il registro, accorgendosi che non c'era piu' nessuno: ma
  /// a quel punto l'uscita era fatta, e le regole lasciano cancellare il
  /// recapito di un telefono solo al suo padrone **collegato**. La
  /// cancellazione veniva rifiutata in silenzio, e il telefono continuava a
  /// ricevere le notifiche di chi era uscito — le sfide con il nome e la frase
  /// dentro — anche nelle mani di un altro.
  ///
  /// Con un limite: senza rete si esce lo stesso, non si resta chiusi dentro
  /// per un recapito.
  Future<void> _staccaIlTelefono() async {
    try {
      await ref
          .read(pushRegistryProvider)
          ?.forget()
          .timeout(const Duration(seconds: 5));
    } on Object catch (_) {
      // Pazienza: ci riprova il registro, all'uscita.
    }
  }

  Future<void> resendVerificationEmail() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(_authRepository.sendEmailVerification);
  }

  /// Manda il messaggio per rifarsi la password.
  ///
  /// Torna `true` se e' partito senza intoppi. **Non torna se quell'account
  /// esista**: quello non lo sa nemmeno il repository, ed e' voluto.
  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => _authRepository.sendPasswordReset(email: email),
    );

    return !state.hasError;
  }

  /// Richiede lo stato aggiornato dell'utente. Torna `true` se nel frattempo
  /// l'indirizzo e' stato confermato.
  Future<bool> refreshVerification() async {
    final result = await AsyncValue.guard(_authRepository.reload);

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);

      return false;
    }

    return result.valueOrNull?.emailVerified ?? false;
  }
}
