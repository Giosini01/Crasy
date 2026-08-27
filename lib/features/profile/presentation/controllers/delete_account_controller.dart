import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cancellare il proprio account.
///
/// **L'ordine e' dati prima, accesso dopo**, e non e' indifferente. Al
/// contrario — account cancellato per primo — le regole del database
/// smetterebbero di riconoscere quella persona a meta' lavoro, e tutto quello
/// che resta diventerebbe impossibile da cancellare per chiunque: dati orfani
/// senza piu' nessuno che abbia il diritto di toglierli.
///
/// La password si chiede una volta sola e viene usata subito: non si tiene da
/// nessuna parte.
class DeleteAccountController extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Torna `true` se l'account non c'e' piu'.
  Future<bool> delete(String password) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      return false;
    }

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      await ref
          .read(userProfileRepositoryProvider)
          .eraseUserData(authState.user.id);

      await ref.read(authRepositoryProvider).deleteAccount(password: password);
    });

    return !state.hasError;
  }
}

final deleteAccountControllerProvider =
    AsyncNotifierProvider<DeleteAccountController, void>(
      DeleteAccountController.new,
    );
