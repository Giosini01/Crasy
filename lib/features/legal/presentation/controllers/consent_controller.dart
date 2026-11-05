import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Cosa e' stato accettato da chi non ha ancora fatto l'accesso.**
///
/// I Termini si accettano prima di registrarsi o di entrare, e in quel momento
/// non c'e' nessun account a cui intestare la firma. Resta qui, in memoria, per
/// il tempo che passa fra la spunta e l'accesso.
///
/// **Sta in memoria e non sul telefono, di proposito.** Salvata sul telefono, la
/// spunta di una persona varrebbe anche per la prossima che entra da li', e
/// un'accettazione fatta da qualcun altro non dimostra niente. Si consuma al
/// primo accesso: chi esce e rientra la ridà, e chi chiude l'app a meta' anche.
class PendingConsent {
  const PendingConsent({required this.version, required this.marketing});

  final String version;
  final bool marketing;
}

final pendingConsentProvider = StateProvider<PendingConsent?>((ref) => null);

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

  Future<void> accept({required bool marketing}) async {
    final authState = ref.read(authStateProvider);

    // **Prima dell'accesso la firma si tiene da parte.** La scrive
    // `consentSyncProvider` nell'istante in cui esiste un account; fino ad
    // allora il router lascia passare soltanto verso la schermata di accesso.
    if (authState is! AuthenticatedAuthState) {
      ref.read(pendingConsentProvider.notifier).state = PendingConsent(
        version: LegalTexts.version,
        marketing: marketing,
      );

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
            origine: 'dentro-l-app',
          ),
    );
  }

  /// **Cambiare idea sulle comunicazioni commerciali non e' riaccettare i
  /// Termini.** Passando da [accept] ogni tocco sull'interruttore riscriveva la
  /// data di accettazione dei documenti, e "documenti accettati il..." diceva
  /// una cosa falsa.
  Future<void> setMarketing({required bool marketing}) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      return;
    }

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(userProfileRepositoryProvider)
          .saveMarketingChoice(userId: authState.user.id, marketing: marketing),
    );
  }
}

final consentControllerProvider =
    AsyncNotifierProvider<ConsentController, void>(ConsentController.new);

/// **La firma data prima dell'accesso, scritta appena c'e' a chi intestarla.**
///
/// Sta qui e non nel controller dell'accesso per non toccarlo: accesso e
/// registrazione funzionano come sempre, e da questo punto si vede soltanto che
/// una sessione e' nata. Vale per qualunque strada ci abbia portato.
///
/// Se la scrittura non riesce, la firma si butta: il router manda alla
/// schermata dei consensi, dove si riprova con l'errore a vista. Un'accettazione
/// che non e' arrivata sul server non e' un'accettazione.
final consentSyncProvider = Provider<void>((ref) {
  var inCorso = false;

  Future<void> registra(String userId, PendingConsent firma) async {
    inCorso = true;

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .saveConsent(
            userId: userId,
            version: firma.version,
            marketing: firma.marketing,
            origine: 'prima-dell-accesso',
          );
    } on Object catch (_) {
      // Ci pensa la schermata dei consensi: vedi qui sopra.
    } finally {
      inCorso = false;
      ref.read(pendingConsentProvider.notifier).state = null;
    }
  }

  ref.listen<AuthState>(authStateProvider, (_, stato) {
    final firma = ref.read(pendingConsentProvider);

    if (stato is AuthenticatedAuthState && firma != null && !inCorso) {
      registra(stato.user.id, firma);
    }
  }, fireImmediately: true);
});
