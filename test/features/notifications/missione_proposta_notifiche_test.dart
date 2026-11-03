import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/domain/entities/notification_topic.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// **La risposta su una missione proposta.**
///
/// Chi ha scritto una missione ferma in controllo sta aspettando, e questa e'
/// l'unica notizia che gliela porta: se si perde, resta ad aspettare per sempre.
void main() {
  group('come la scrive il server', () {
    test('approvata con un premio: si sa quale proposta pagare', () {
      final riga = FirestoreNotificationsRepository.daDocumento('n1', {
        'kind': 'missionApproved',
        'actorId': '',
        'actorUsername': '',
        'challengeId': '',
        'challengeTitle': 'Foto al balcone',
        'propostaId': 'p1',
        'motivo': '',
        'premioCents': 500,
        'dalServer': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 3)),
      });

      expect(riga, isNotNull);
      expect(riga!.kind, NotificationKind.missionApproved);
      expect(riga.propostaId, 'p1');
      expect(riga.premioCents, 500);
      expect(riga.challengeId, isEmpty);
      expect(riga.challengeTitle, 'Foto al balcone');
      expect(riga.createdAt, DateTime(2026, 11, 3));
    });

    test('rifiutata: porta il motivo che ha scritto chi ha deciso', () {
      final riga = FirestoreNotificationsRepository.daDocumento('n2', {
        'kind': 'missionRejected',
        'challengeId': '',
        'challengeTitle': 'Foto in autostrada',
        'propostaId': 'p2',
        'motivo': 'chiede di guidare col telefono in mano',
      });

      expect(riga!.kind, NotificationKind.missionRejected);
      expect(riga.motivo, 'chiede di guidare col telefono in mano');
    });

    test('un tipo che quest\'app non conosce non si mostra', () {
      expect(
        FirestoreNotificationsRepository.daDocumento('n3', {
          'kind': 'moderazione',
        }),
        isNull,
      );
    });
  });

  group('cosa dice la riga', () {
    test('approvata e gratis e\' gia\' in gara', () {
      const riga = AppNotification(
        id: 'x',
        kind: NotificationKind.missionApproved,
        challengeId: 'g',
      );

      expect(riga.message, contains('è in gara'));
    });

    test('approvata con un premio aspetta il pagamento', () {
      const riga = AppNotification(
        id: 'x',
        kind: NotificationKind.missionApproved,
        propostaId: 'p',
        premioCents: 500,
      );

      expect(riga.message, contains('paga il premio'));
    });

    test('rifiutata dice dove guardare, non il motivo', () {
      // Il motivo sta nel foglio: la riga la leggono anche gli altri, se il
      // telefono e' in mano a qualcuno.
      const riga = AppNotification(
        id: 'x',
        kind: NotificationKind.missionRejected,
        motivo: 'un motivo',
      );

      expect(riga.message, contains('tocca per sapere perché'));
      expect(riga.message, isNot(contains('un motivo')));
    });
  });

  group('dove sta', () {
    test('con le proprie missioni', () {
      for (final kind in [
        NotificationKind.missionApproved,
        NotificationKind.missionRejected,
      ]) {
        expect(AppNotification.groupOf(kind), NotificationGroup.participations);
      }
    });

    test('non si puo\' spegnere', () {
      // Come nel server: `ARGOMENTO` in `functions/index.js` non le ha.
      expect(NotificationTopic.of(NotificationKind.missionApproved), isNull);
      expect(NotificationTopic.of(NotificationKind.missionRejected), isNull);
    });
  });

  group('il tocco sulla notifica', () {
    PushTap tocco(Map<String, String> dati) => pushTapOf(dati, daFermo: false);

    test('porta in campanella, sulla riga giusta', () {
      for (final kind in ['missionApproved', 'missionRejected']) {
        final dove = tocco({
          'kind': kind,
          'challengeId': '',
          'notificationId': 'n1',
        });

        expect(
          dove.apri,
          '${AppRoutes.notifications}?sezione=participations',
          reason: kind,
        );
        expect(dove.evidenzia, 'n1', reason: kind);
      }
    });

    test('quella per chi modera, sulla sua app, non rompe niente', () {
      // Il server la manda ai telefoni di chi modera, senza una gara: e' un tipo
      // che l'app non conosce, e porta alle gare come ogni annuncio senza tipo.
      final dove = tocco({'kind': 'moderazione', 'challengeId': ''});

      expect(dove.apri, isNull);
      expect(dove.scheda, AppRoutes.challenges);
    });
  });
}
