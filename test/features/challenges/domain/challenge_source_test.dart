import 'package:crasy/features/challenges/data/mappers/challenge_mapper.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Da dove arriva la roba che si manda in gara.
///
/// **La prova piu' importante e' quella sul ripiego.** Ci sono migliaia di gare
/// scritte prima che questo campo esistesse, e nessuna ce l'ha. Se una gara
/// senza `source` venisse letta come d'archivio, si aprirebbe la galleria su
/// tutto lo storico di CRASY — e la regola che tiene in piedi il prodotto
/// sarebbe saltata in silenzio, senza un errore da nessuna parte.
void main() {
  Challenge gara({ChallengeSource source = ChallengeSource.instant}) => Challenge(
    id: 'g1',
    title: 'UNA GARA',
    brief: 'Fai una cosa.',
    prizeCents: 1000,
    scope: ChallengeScope.global,
    source: source,
    startsAt: DateTime(2026, 1, 1, 10),
    endsAt: DateTime(2026, 1, 1, 12),
  );

  group('come si legge dal database', () {
    test('una gara senza il campo e istantanea', () {
      // E' il caso di tutte quelle nate prima di oggi.
      expect(ChallengeSource.fromName(null), ChallengeSource.instant);
    });

    test('una parola che non conosciamo non apre la galleria', () {
      // Un valore inventato, o storpiato da una versione futura, non deve
      // atterrare sul caso permissivo.
      expect(ChallengeSource.fromName('archivio'), ChallengeSource.instant);
      expect(ChallengeSource.fromName(''), ChallengeSource.instant);
      expect(ChallengeSource.fromName('ARCHIVE'), ChallengeSource.instant);
    });

    test('archive si legge, ed e la sola parola che lo fa', () {
      expect(ChallengeSource.fromName('archive'), ChallengeSource.archive);
      expect(ChallengeSource.fromName('instant'), ChallengeSource.instant);
    });
  });

  group('il giro completo dal database e ritorno', () {
    test('una gara d archivio resta d archivio', () {
      final scritta = ChallengeMapper.toCreateMap(
        gara(source: ChallengeSource.archive),
      );

      expect(scritta['source'], 'archive');

      final riletta = ChallengeMapper.fromFirestore('g1', {
        ...scritta,
        // Le date tornano indietro come le scrive Firestore; qui basta che il
        // campo che ci interessa sopravviva al giro.
        'startsAt': null,
        'endsAt': null,
      });

      expect(riletta.source, ChallengeSource.archive);
      expect(riletta.source.isArchive, isTrue);
      expect(riletta.source.isInstant, isFalse);
    });

    test('un documento vecchio, senza il campo, torna istantaneo', () {
      final vecchia = ChallengeMapper.fromFirestore('g0', {
        'title': 'UNA GARA DI IERI',
        'brief': 'Fai una cosa.',
        'prizeCents': 1000,
        'scope': 'global',
      });

      expect(vecchia.source, ChallengeSource.instant);
    });
  });

  test('le due strade non si sovrappongono mai', () {
    // Detta cosi' sembra ovvia, ed e' la regola su cui poggia tutto il resto:
    // ogni gara ha **una** strada, e chi partecipa non ne ha una seconda.
    for (final source in ChallengeSource.values) {
      expect(source.isArchive, isNot(source.isInstant));
    }
  });

  test('copyWith non se lo perde per strada', () {
    final prima = gara(source: ChallengeSource.archive);
    final dopo = prima.copyWith(title: 'ALTRO TITOLO');

    expect(dopo.source, ChallengeSource.archive);
    // E due gare che differiscono solo per questo non sono la stessa gara: se
    // l'uguaglianza lo ignorasse, cambiare tipo non farebbe ridisegnare niente.
    expect(gara(), isNot(gara(source: ChallengeSource.archive)));
  });
}
