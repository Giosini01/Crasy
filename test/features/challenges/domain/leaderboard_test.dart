import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/leaderboard.dart';
import 'package:flutter_test/flutter_test.dart';

/// **La regola della classifica, e vale piu' di come e' disegnata.**
///
/// Comandano i soldi, non le presenze: chi ha vinto una gara da cento sta sopra
/// a chi ne ha vinte dieci da uno. Non e' una preferenza — e' l'unica lettura
/// che non si possa gonfiare. Contare le partecipazioni premia chi entra
/// dappertutto senza rischiare niente; contare i soldi premia chi ha fatto la
/// cosa piu' difficile, che e' quello che una classifica dovrebbe far venire
/// voglia di fare.
void main() {
  Challenge gara({
    required String id,
    required int prizeCents,
    String lanciata = 'anna',
    String? vinta,
  }) {
    return Challenge(
      id: id,
      title: id,
      brief: 'Fai qualcosa.',
      prizeCents: prizeCents,
      scope: ChallengeScope.global,
      createdByUserId: lanciata,
      createdByUsername: lanciata,
      winnerUserId: vinta ?? '',
      winnerUsername: vinta ?? '',
      winnerEntryId: vinta == null ? null : 'foto',
      startsAt: DateTime(2026),
      endsAt: DateTime(2026, 1, 2),
    );
  }

  test('una vittoria grossa batte dieci vittorie piccole', () {
    final chiuse = [
      for (var i = 0; i < 10; i++)
        gara(id: 'piccola$i', prizeCents: 100, vinta: 'tanteVolte'),
      gara(id: 'grossa', prizeCents: 10000, vinta: 'unaVolta'),
    ];

    final classifica = Leaderboard.winners(chiuse);

    // Dieci euro contro cento: vince chi ha preso cento, anche avendo
    // partecipato una volta sola.
    expect(classifica.first.userId, 'unaVolta');
    expect(classifica.first.count, 1);
    expect(classifica[1].userId, 'tanteVolte');
    expect(classifica[1].count, 10);
  });

  test('a parita\' di soldi conta chi l\'ha fatto piu\' volte', () {
    final chiuse = [
      gara(id: 'a1', prizeCents: 1000, vinta: 'due'),
      gara(id: 'a2', prizeCents: 1000, vinta: 'due'),
      gara(id: 'b1', prizeCents: 2000, vinta: 'uno'),
    ];

    final classifica = Leaderboard.winners(chiuse);

    expect(classifica.first.userId, 'due');
    expect(classifica.first.cents, classifica[1].cents);
  });

  test('si somma il netto, non il premio in vetrina', () {
    final chiuse = [gara(id: 'x', prizeCents: 50000, vinta: 'anna')];

    // E' la cifra che quella persona puo' dire di avere: il premio meno la
    // percentuale di CRASY.
    expect(Leaderboard.winners(chiuse).first.cents, 45000);
  });

  test('le gare gratis non entrano in una classifica di soldi', () {
    final chiuse = [
      gara(id: 'gratis', prizeCents: 0, vinta: 'anna'),
      gara(id: 'vera', prizeCents: 5000, vinta: 'bruno'),
    ];

    final classifica = Leaderboard.winners(chiuse);

    expect(classifica.map((r) => r.userId), ['bruno']);
  });

  test('chi non ha vinto niente non compare', () {
    final chiuse = [gara(id: 'deserta', prizeCents: 5000)];

    expect(Leaderboard.winners(chiuse), isEmpty);
  });

  test('chi fa giocare si conta su quanto ha messo in palio', () {
    final chiuse = [
      gara(id: 'a', prizeCents: 10000, lanciata: 'riccone', vinta: 'x'),
      gara(id: 'b', prizeCents: 500, lanciata: 'assiduo', vinta: 'x'),
      gara(id: 'c', prizeCents: 500, lanciata: 'assiduo', vinta: 'x'),
      gara(id: 'd', prizeCents: 500, lanciata: 'assiduo'),
    ];

    final classifica = Leaderboard.launchers(chiuse);

    // **Anche le gare deserte contano, qui.** Chi mette dei soldi in palio li
    // ha messi comunque: che poi non si sia presentato nessuno non e' merito
    // ne' colpa sua, ed e' proprio il rischio che questa classifica riconosce.
    expect(classifica.first.userId, 'riccone');
    expect(classifica[1].userId, 'assiduo');
    expect(classifica[1].count, 3);
  });

  test('la sfida del giorno non entra fra chi fa giocare', () {
    // Non ha un autore e non costa niente: e' di CRASY, e CRASY non gareggia
    // nemmeno da questa parte.
    final chiuse = [
      gara(id: 'daily', prizeCents: 0, lanciata: '', vinta: 'anna'),
    ];

    expect(Leaderboard.launchers(chiuse), isEmpty);
  });
}
