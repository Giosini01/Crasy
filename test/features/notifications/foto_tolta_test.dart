import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _tolta({String motivo = '', bool automatico = false}) =>
    AppNotification(
      id: 'tolta_g',
      kind: NotificationKind.removed,
      challengeId: 'g',
      motivo: motivo,
      automatico: automatico,
    );

/// **L'avviso di una foto tolta dice perché, e chi l'ha deciso.**
///
/// Il Digital Services Act chiede a chi toglie un contenuto di dire il motivo e
/// se la decisione è automatica. Prima l'avviso diceva solo "la tua foto è
/// stata tolta", e chi lo riceveva non sapeva né perché né cosa farci.
void main() {
  test('il controllo automatico si dichiara', () {
    expect(
      _tolta(motivo: 'sessuale', automatico: true).perche,
      "Il controllo automatico l'ha considerata un contenuto sessuale.",
    );
    expect(
      _tolta(motivo: 'violenza', automatico: true).perche,
      "Il controllo automatico l'ha considerata un contenuto violento.",
    );
  });

  test('una persona del team, dopo una segnalazione', () {
    expect(
      _tolta(motivo: 'pericolo').perche,
      'Dopo una segnalazione, una persona del team '
      "l'ha considerata un contenuto che mette in pericolo qualcuno.",
    );
  });

  test('senza un motivo noto non si inventa niente', () {
    expect(
      _tolta(automatico: true).perche,
      "Il controllo automatico l'ha considerata fuori dalle regole.",
    );
    // Gli avvisi scritti prima che portassero il motivo.
    expect(_tolta().perche, 'Non rispettava le regole delle missioni.');
  });

  test('la foto rimessa in gara ha la sua riga', () {
    const rimessa = AppNotification(
      id: 'rimessa_g',
      kind: NotificationKind.restored,
      challengeId: 'g',
    );

    expect(rimessa.message, 'La tua foto è tornata in gara');
    expect(AppNotification.kindFromName('restored'), NotificationKind.restored);
  });
}
