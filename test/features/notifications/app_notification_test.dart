import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ora = DateTime(2026, 8, 19, 12);

  test('e\' nuova se e\' arrivata dopo l\'ultima occhiata', () {
    const notification = AppNotification(id: 'x', kind: NotificationKind.fire);

    expect(
      AppNotification(
        id: 'x',
        kind: NotificationKind.fire,
        createdAt: ora,
      ).isUnreadSince(ora.subtract(const Duration(minutes: 1))),
      isTrue,
    );

    expect(
      AppNotification(
        id: 'x',
        kind: NotificationKind.fire,
        createdAt: ora,
      ).isUnreadSince(ora.add(const Duration(minutes: 1))),
      isFalse,
    );

    // Senza data si mostra: nel dubbio si fa vedere, che e' l'errore meno
    // grave dei due.
    expect(notification.isUnreadSince(ora), isTrue);
  });

  test('chi non ha mai aperto la campanella le ha tutte nuove', () {
    expect(
      AppNotification(
        id: 'x',
        kind: NotificationKind.win,
        createdAt: ora,
      ).isUnreadSince(null),
      isTrue,
    );
  });

  test('ogni tipo ha la sua frase', () {
    const actor = 'giulia';

    expect(
      const AppNotification(
        id: '1',
        kind: NotificationKind.fire,
        actorUsername: actor,
      ).message,
      contains('fiamma'),
    );
    expect(
      const AppNotification(
        id: '2',
        kind: NotificationKind.participation,
        actorUsername: actor,
      ).message,
      contains('partecipato'),
    );
    expect(
      const AppNotification(id: '3', kind: NotificationKind.win).message,
      'Hai vinto',
    );
  });

  test('un tipo sconosciuto non fa saltare la campanella', () {
    expect(AppNotification.kindFromName('boh'), NotificationKind.fire);
    expect(AppNotification.kindFromName('win'), NotificationKind.win);
  });

  group('le sezioni e gli avvisi della scelta', () {
    test('ogni tipo finisce nella sua sezione', () {
      const casi = {
        NotificationKind.participation: NotificationGroup.missions,
        NotificationKind.win: NotificationGroup.missions,
        NotificationKind.ended: NotificationGroup.missions,
        NotificationKind.fire: NotificationGroup.fires,
        // Le richieste d'amicizia non hanno una sezione qui: stanno nella
        // scheda Amici, con i comandi per accettare o rifiutare.
        NotificationKind.friendRequest: NotificationGroup.missions,
      };

      casi.forEach((kind, gruppo) {
        expect(
          AppNotification(id: 'x', kind: kind).group,
          gruppo,
          reason: kind.name,
        );
      });
    });

    test('a gara finita si dice che e\' finita', () {
      const notification = AppNotification(
        id: 'finita_1',
        kind: NotificationKind.ended,
      );

      // **Non nomina nessuno**, e non e' una svista: non c'e' piu' nessuno che
      // decide, quindi non c'e' nessuno da nominare. C'e' solo un conteggio da
      // andare a guardare.
      expect(notification.message, contains('finita'));
      expect(notification.message, isNot(contains('@')));
    });
  });
}
