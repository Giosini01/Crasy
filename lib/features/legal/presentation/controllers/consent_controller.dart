import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registra le scelte fatte nella schermata dei consensi.
///
/// **La versione non arriva da chi chiama.** La legge [LegalTexts.version] qui
/// dentro, ed e' voluto: se la passasse la schermata, prima o poi due
/// schermate diverse ne scriverebbero due diverse, e a quel punto "questa
/// persona ha accettato la versione corrente" smetterebbe di voler dire
/// qualcosa.
///
/// Le obbligatorie non sono parametri per la stessa ragione: se si e' arrivati
/// a chiamare questo metodo sono state spuntate tutte — la schermata non lascia
/// proseguire altrimenti — e passarle vorrebbe dire ammettere la possibilita'
/// di registrare un consenso incompleto.
class ConsentController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> accept({
    required bool marketing,
    required bool profiling,
  }) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      return;
    }

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(userProfileRepositoryProvider)
          .saveConsent(
            userId: authState.user.id,
            version: LegalTexts.version,
            marketing: marketing,
            profiling: profiling,
          ),
    );
  }
}

final consentControllerProvider =
    AsyncNotifierProvider<ConsentController, void>(ConsentController.new);
