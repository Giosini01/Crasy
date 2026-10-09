import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/domain/entities/notification_topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gli interruttori coprono tutte le notifiche', () {
    test('ogni tipo ha un interruttore, tranne quello che non si spegne', () {
      // **Il controllo che vale piu' di tutti gli altri qui.** Un tipo nuovo
      // aggiunto senza metterlo in un argomento diventa una notifica che non si
      // puo' spegnere, e nessuno se ne accorge: il foglio delle impostazioni
      // continua a sembrare completo, e chi aveva spento tutto si ritrova il
      // telefono che squilla senza capire da dove.
      final senzaInterruttore = [
        for (final kind in NotificationKind.values)
          if (NotificationTopic.of(kind) == null) kind,
      ];

      expect(senzaInterruttore, [NotificationKind.removed]);
    });

    test('nessun tipo sta sotto due interruttori', () {
      // Due interruttori sulla stessa notizia vogliono dire che spegnerne uno
      // non la spegne, e il foglio mente.
      for (final kind in NotificationKind.values) {
        final quanti = NotificationTopic.values
            .where((topic) => topic.kinds.contains(kind))
            .length;

        expect(quanti, lessThanOrEqualTo(1), reason: kind.name);
      }
    });
  });

  group('le scelte', () {
    test('senza niente salvato sono tutte accese', () {
      final prefs = NotificationPrefs.fromMap(null);

      for (final topic in NotificationTopic.values) {
        expect(prefs.vuole(topic), isTrue, reason: topic.name);
      }
    });

    test('un documento vuoto le lascia tutte accese', () {
      // E' il caso di chi apre la schermata, guarda, e la chiude: il documento
      // nasce vuoto e non deve spegnere niente.
      expect(NotificationPrefs.fromMap(const {}).quanteSpente, 0);
    });

    test('un argomento aggiunto domani parte accesso', () {
      // Si tiene l'elenco degli spenti, quindi un campo che non c'e' e' acceso.
      // Senza questo, ogni argomento nuovo nascerebbe spento per tutti quelli
      // che hanno gia' salvato una scelta.
      final prefs = NotificationPrefs.fromMap(const {'fiamme': false});

      expect(prefs.vuole(NotificationTopic.fiamme), isFalse);
      expect(prefs.vuole(NotificationTopic.rivali), isTrue);
    });

    test('si spegne e si riaccende, e il resto non si muove', () {
      final spenta = NotificationPrefs.tutte.con(
        NotificationTopic.fiamme,
        accesa: false,
      );

      expect(spenta.vuole(NotificationTopic.fiamme), isFalse);
      expect(spenta.vuole(NotificationTopic.commenti), isTrue);

      final riaccesa = spenta.con(NotificationTopic.fiamme, accesa: true);

      expect(riaccesa.quanteSpente, 0);
    });

    test('si scrive tutto, anche quello che resta accesso', () {
      // Un documento con tre campi su otto non si legge: chi ci mette gli occhi
      // sopra per capire perche' una notifica non e' arrivata deve trovare
      // l'elenco intero.
      final mappa = NotificationPrefs.tutte
          .con(NotificationTopic.sfide, accesa: false)
          .toMap();

      expect(mappa.length, NotificationTopic.values.length);
      expect(mappa['sfide'], isFalse);
      expect(mappa['vittorie'], isTrue);
    });

    test('quello che si scrive si rilegge uguale', () {
      final prima = NotificationPrefs.tutte
          .con(NotificationTopic.rivali, accesa: false)
          .con(NotificationTopic.promemoria, accesa: false);

      final dopo = NotificationPrefs.fromMap(prima.toMap());

      expect(dopo.spente, prima.spente);
    });
  });

  group('la notifica nuova', () {
    test('sta con le partecipazioni e non indovina il genere', () {
      const notifica = AppNotification(
        id: 'rivale_gara_tizio',
        kind: NotificationKind.rival,
        actorUsername: 'tizio',
      );

      expect(notifica.group, NotificationGroup.participations);
      expect(notifica.message, '@tizio prova a batterti');
    });

    test('non e la stessa cosa di una partecipazione', () {
      // Le due notizie raccontano lo stesso fatto a due persone diverse, e dire
      // la stessa frase a tutte e due vorrebbe dire dare a chi partecipa la
      // frase di chi ha lanciato la gara.
      const partecipazione = AppNotification(
        id: 'p',
        kind: NotificationKind.participation,
        actorUsername: 'tizio',
      );

      const rivale = AppNotification(
        id: 'r',
        kind: NotificationKind.rival,
        actorUsername: 'tizio',
      );

      expect(rivale.message, isNot(partecipazione.message));
    });
  });
}
