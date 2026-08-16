import 'package:crasy/features/auth/domain/repositories/auth_repository.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
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

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(_authRepository.signOut);
  }

  Future<void> resendVerificationEmail() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(_authRepository.sendEmailVerification);
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
