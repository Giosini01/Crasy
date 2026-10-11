import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/missione_pronta.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('le missioni già scritte', () {
    test('passano tutte la validazione del modulo', () {
      // **È il controllo che vale più di tutti gli altri qui.** Una missione
      // pronta che non passa i controlli del modulo è peggio di nessuna
      // missione pronta: si tocca, i campi si riempiono da soli, e il tasto
      // per mandarla resta spento senza che si capisca perché.
      for (final pronta in MissionePronta.tutte) {
        expect(
          ChallengeDraftValidators.validateTitle(pronta.titolo),
          isNull,
          reason: 'titolo: ${pronta.titolo}',
        );

        expect(
          ChallengeDraftValidators.validateBrief(pronta.consegna),
          isNull,
          reason: 'consegna: ${pronta.titolo}',
        );
      }
    });

    test('nessuna si chiama come un\'altra', () {
      // Due righe identiche in una fila da sfogliare si leggono come un
      // difetto, e chi scorre si ferma a capire se ha già visto quella.
      final titoli = {for (final p in MissionePronta.tutte) p.titolo};

      expect(titoli.length, MissionePronta.tutte.length);
    });

    test('la maggior parte si fa adesso, non in archivio', () {
      // L'istantanea è quello che CRASY è. L'archivio esiste per le missioni
      // che altrimenti non si potrebbero fare — una foto di dieci anni fa non
      // si scatta — e se diventasse la norma nel menù, il menù direbbe che
      // CRASY è un'altra cosa.
      final adesso = MissionePronta.tutte
          .where((p) => p.source == ChallengeSource.instant)
          .length;

      expect(adesso * 2, greaterThan(MissionePronta.tutte.length));
    });

    test('ce ne sono abbastanza da far scorrere', () {
      // Con tre o quattro si legge come un elenco chiuso: si guardano tutte,
      // non piace nessuna, e si torna al foglio bianco con l'idea che non ci
      // sia altro.
      expect(MissionePronta.tutte.length, greaterThanOrEqualTo(8));
    });

    test('i titoli si leggono senza aprire', () {
      // Il titolo è spesso l'unica cosa che si legge: se serve la consegna per
      // capire cosa c'è da fare, quella missione in una fila da sfogliare non
      // viene scelta mai.
      for (final pronta in MissionePronta.tutte) {
        expect(
          pronta.titolo.length,
          lessThanOrEqualTo(44),
          reason: 'troppo lungo per una scheda: ${pronta.titolo}',
        );
      }
    });
  });
}
