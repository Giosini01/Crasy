import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_catalogo_missioni.dart';
import 'package:crasy/features/challenges/domain/entities/missione_pronta.dart';
import 'package:crasy/features/challenges/domain/repositories/catalogo_missioni.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final catalogoMissioniProvider = Provider<CatalogoMissioni>((ref) {
  return FirestoreCatalogoMissioni(ref.watch(firebaseFirestoreProvider));
});

/// **Le missioni da consigliare a chi apre adesso la schermata di creazione.**
///
/// `autoDispose`: si spegne quando si esce dalla schermata, e riaprendola si
/// rifà il conto col nuovo orologio. **Dentro la schermata non si muove**, perché
/// la schermata lo guarda finché è aperta: un elenco che cambia mentre si sta
/// scegliendo è la cosa più fastidiosa che possa fare.
final missioniDelGiroProvider =
    FutureProvider.autoDispose<List<MissionePronta>>((ref) async {
      final adesso = DateTime.now();

      // Senza Firebase l'app gira sugli esempi, e le prove senza rete: qui lo
      // stesso, con le scorte.
      if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
        return _scorte(adesso);
      }

      return missioniDelGiro(
        ref.watch(catalogoMissioniProvider),
        chi: ref.watch(currentUserIdProvider) ?? '',
        quando: adesso,
      );
    });

/// **Il giro di adesso: dieci missioni per questa persona in questi dieci
/// minuti.**
///
/// **Un guasto non lascia il foglio bianco.** Se il catalogo non risponde, o è
/// vuoto, restano le scorte scritte nell'app: per chi non ha un'idea, questa fila
/// è il motivo per cui lancia una gara.
Future<List<MissionePronta>> missioniDelGiro(
  CatalogoMissioni catalogo, {
  required String chi,
  required DateTime quando,
}) async {
  try {
    final totale = await catalogo.quante();

    if (totale > 0) {
      final posto = MissionePronta.postoDelGiro(
        chi: chi,
        quando: quando,
        totale: totale,
      );
      final lette = await catalogo.daPosto(
        posto,
        MissionePronta.quanteAllaVolta,
      );
      final buone = lette.where(_passaIlModulo).toList();

      if (buone.isNotEmpty) {
        return [
          ...MissionePronta.diStagione(quando),
          ...MissionePronta.aTurno(buone),
        ];
      }
    }
  } on Object catch (errore) {
    debugPrint('CRASY: catalogo delle missioni non letto — $errore');
  }

  return _scorte(quando);
}

List<MissionePronta> _scorte(DateTime quando) {
  return MissionePronta.diOggi(
    quando,
  ).take(MissionePronta.quanteAllaVolta).toList();
}

/// **Una missione che il modulo rifiuterebbe non si consiglia.**
///
/// Il catalogo si può cambiare senza pubblicare un'app, e la prova sul file non
/// vede quello che qualcuno scrive a mano nel database: si tocca, i campi si
/// riempiono, e il tasto per mandarla resta spento senza che si capisca perché.
bool _passaIlModulo(MissionePronta pronta) {
  return ChallengeDraftValidators.validateTitle(pronta.titolo) == null &&
      ChallengeDraftValidators.validateBrief(pronta.consegna) == null;
}
