import 'dart:async';

import 'package:crasy/core/theme/seasons/season.dart';

/// **Le prove girano sempre fuori stagione.**
///
/// `flutter_test` carica questo file da solo, prima di ogni prova, e quello che
/// fa e' una riga: inchioda la stagione a [Season.base].
///
/// Senza, dal 20 ottobre al 2 novembre quattrocentosessanta prove girerebbero su
/// un'app con le ragnatele addosso — e la prova che misura la fiamma
/// dell'apertura non troverebbe una fiamma. Cadrebbero il 20 ottobre, si
/// riaggiusterebbero da sole il 3 novembre, e nel frattempo qualcuno passerebbe
/// un pomeriggio a cercare cosa ha rotto.
///
/// **Una prova non deve mai leggere l'orologio vero.** Vale qui come vale per le
/// scadenze delle challenge: una prova che passa o cade a seconda del giorno in
/// cui gira non sta misurando il programma.
///
/// Chi vuole provare una stagione la fissa lui, dentro la sua prova.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Season.fissata = Season.base;

  await testMain();
}
