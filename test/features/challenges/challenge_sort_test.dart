import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_sort.dart';
import 'package:flutter_test/flutter_test.dart';

/// **In che ordine si guardano le missioni.**
///
/// Un ordinamento sbagliato non si schianta e non scrive niente da nessuna
/// parte: mostra una lista plausibile con dentro l'ordine sbagliato, e chi
/// guarda pensa che quelle siano tutte le missioni che ci sono. E' il motivo
/// per cui sta in una funzione sua, provata qui, invece che dentro la
/// schermata.
void main() {
  final ora = DateTime(2026, 10, 1, 12);

  Challenge gara({
    required String id,
    int premio = 0,
    int finisceFra = 1,
    int natoGiorniFa = 0,
  }) {
    return Challenge(
      id: id,
      title: id,
      brief: 'x',
      prizeCents: premio,
      scope: ChallengeScope.global,
      startsAt: ora.subtract(Duration(days: natoGiorniFa)),
      endsAt: ora.add(Duration(hours: finisceFra)),
    );
  }

  final tutte = [
    gara(id: 'media', premio: 500, finisceFra: 5, natoGiorniFa: 1),
    gara(id: 'ricca', premio: 2000, finisceFra: 9, natoGiorniFa: 3),
    gara(id: 'gratis', premio: 0, finisceFra: 2, natoGiorniFa: 0),
  ];

  List<String> nomi(ChallengeSort come) =>
      [for (final g in ordina(tutte, come)) g.id];

  test('in scadenza: prima quella che chiude fra poco', () {
    expect(nomi(ChallengeSort.inScadenza), ['gratis', 'media', 'ricca']);
  });

  test('premio alto: i soldi davanti', () {
    expect(nomi(ChallengeSort.premioAlto), ['ricca', 'media', 'gratis']);
  });

  test('premio basso: le gratis davanti', () {
    expect(nomi(ChallengeSort.premioBasso), ['gratis', 'media', 'ricca']);
  });

  test('nuove: l\'ultima arrivata in cima', () {
    expect(nomi(ChallengeSort.recenti), ['gratis', 'media', 'ricca']);
  });

  test('meno recenti: il contrario esatto', () {
    expect(nomi(ChallengeSort.vecchie), ['ricca', 'media', 'gratis']);
  });

  test('a parita\' di premio decide la scadenza', () {
    // **Senza questa regola la lista si rimescola da sola.** Le gratis hanno
    // tutte lo stesso premio: senza un secondo criterio il loro ordine
    // dipenderebbe da come sono arrivate, e cambierebbe a ogni apertura della
    // schermata. Una lista che si rimescola fa sembrare rotta anche la parte
    // che funziona.
    final tutteGratis = [
      gara(id: 'dopo', finisceFra: 9),
      gara(id: 'prima', finisceFra: 1),
      gara(id: 'mezzo', finisceFra: 5),
    ];

    expect(
      [for (final g in ordina(tutteGratis, ChallengeSort.premioAlto)) g.id],
      ['prima', 'mezzo', 'dopo'],
    );
    expect(
      [for (final g in ordina(tutteGratis, ChallengeSort.premioBasso)) g.id],
      ['prima', 'mezzo', 'dopo'],
    );
  });

  test('la lista di partenza non si tocca', () {
    // Ordinare sul posto quella che arriva dal provider vorrebbe dire cambiare
    // una cosa che non e' nostra: altre schermate la stanno guardando, e si
    // ritroverebbero l'ordine cambiato sotto gli occhi senza motivo.
    final prima = [for (final g in tutte) g.id];

    ordina(tutte, ChallengeSort.premioAlto);

    expect([for (final g in tutte) g.id], prima);
  });

  test('una lista vuota resta vuota, senza lamentarsi', () {
    expect(ordina(const [], ChallengeSort.premioAlto), isEmpty);
  });
}
