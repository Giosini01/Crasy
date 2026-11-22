import 'package:crasy/features/challenges/data/mappers/challenge_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Il premio di CRASY si legge dalla gara.**
///
/// Le missioni del fondo escono a nome di una persona vera ma le paga CRASY, e
/// l'app lo scrive accanto al nome. Se il campo non si leggesse, la gara
/// sembrerebbe pagata da chi la firma: nessun errore, solo un'informazione
/// sbagliata davanti a chi decide se partecipare.
void main() {
  Map<String, dynamic> gara([Map<String, dynamic> altro = const {}]) => {
    'title': 'TU DA PICCOLO',
    'brief': 'Una foto di quando eri bambino.',
    'prizeCents': 150,
    'scope': 'global',
    'createdByUserId': 'ilaria',
    'createdByUsername': 'ilariap',
    ...altro,
  };

  test('una missione del fondo dice che il premio e di CRASY', () {
    final letta = ChallengeMapper.fromFirestore(
      'g',
      gara({'pagataDalFondo': true}),
    );

    expect(letta.paidByCrasy, isTrue);
    // E resta di chi la firma: nome, faccia e profilo sono i suoi.
    expect(letta.createdByUsername, 'ilariap');
    expect(letta.byCrasy, isFalse);
  });

  test('tutte le altre il premio lo hanno pagato da sole', () {
    expect(ChallengeMapper.fromFirestore('g', gara()).paidByCrasy, isFalse);
    expect(
      ChallengeMapper.fromFirestore(
        'g',
        gara({'pagataDalFondo': false}),
      ).paidByCrasy,
      isFalse,
    );
  });

  test('il segno sopravvive a una copia', () {
    final letta = ChallengeMapper.fromFirestore(
      'g',
      gara({'pagataDalFondo': true}),
    );

    expect(letta.copyWith(title: 'ALTRO').paidByCrasy, isTrue);
    expect(letta == letta.copyWith(paidByCrasy: false), isFalse);
  });
}
