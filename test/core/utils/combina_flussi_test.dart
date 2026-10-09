import 'dart:async';

import 'package:crasy/core/utils/combina_flussi.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Guardare due flussi insieme, e continuare a guardarli.**
///
/// La prova che conta e' la prima, ed e' il difetto vero: con `asyncExpand`
/// annidato il valore esterno veniva letto **una volta sola** e poi restava
/// fermo, perche' quel metodo aspetta che il flusso interno finisca — e un
/// ascolto su un database non finisce mai.
///
/// Nel portafoglio voleva dire soldi spesi che non venivano scalati: la riga
/// del pagamento compariva nell'elenco e il saldo sopra non si muoveva.
void main() {
  group('tutti e due restano ascoltati', () {
    test('un cambiamento del primo arriva anche dopo il primo giro', () async {
      final saldo = StreamController<int>();
      final righe = StreamController<String>();

      final visti = <String>[];
      final sub = combinaDue(
        saldo.stream,
        righe.stream,
        (int s, String r) => '$s/$r',
      ).listen(visti.add);

      saldo.add(100);
      righe.add('vuoto');
      await pump();

      // **Qui cadeva la versione annidata.** Questo secondo valore del primo
      // flusso non veniva mai letto: il saldo restava 100 per sempre.
      saldo.add(50);
      await pump();

      expect(visti, ['100/vuoto', '50/vuoto']);

      await sub.cancel();
      await saldo.close();
      await righe.close();
    });

    test('e un cambiamento del secondo pure', () async {
      final saldo = StreamController<int>();
      final righe = StreamController<String>();
      final visti = <String>[];
      final sub = combinaDue(
        saldo.stream,
        righe.stream,
        (int s, String r) => '$s/$r',
      ).listen(visti.add);

      saldo.add(100);
      righe.add('a');
      righe.add('b');
      await pump();

      expect(visti, ['100/a', '100/b']);

      await sub.cancel();
      await saldo.close();
      await righe.close();
    });
  });

  group('prima che ci siano tutti e due', () {
    test('non emette niente con uno solo', () async {
      final saldo = StreamController<int>();
      final righe = StreamController<String>();
      final visti = <String>[];
      final sub = combinaDue(
        saldo.stream,
        righe.stream,
        (int s, String r) => '$s/$r',
      ).listen(visti.add);

      saldo.add(100);
      saldo.add(200);
      await pump();

      // Un portafoglio con il saldo e senza i movimenti e' mezzo portafoglio, e
      // mezzo portafoglio a schermo e' un lampeggio.
      expect(visti, isEmpty);

      righe.add('a');
      await pump();

      // Appena arriva il secondo si usa **l'ultimo** valore del primo, non il
      // primo che era arrivato.
      expect(visti, ['200/a']);

      await sub.cancel();
      await saldo.close();
      await righe.close();
    });
  });

  group('quando la schermata se ne va', () {
    test('disdice tutti e due gli ascolti sotto', () async {
      var primoVivo = false;
      var secondoVivo = false;

      final uno = StreamController<int>(
        onListen: () => primoVivo = true,
        onCancel: () => primoVivo = false,
      );
      final due = StreamController<int>(
        onListen: () => secondoVivo = true,
        onCancel: () => secondoVivo = false,
      );

      final sub = combinaDue(
        uno.stream,
        due.stream,
        (a, b) => a + b,
      ).listen((_) {});
      await pump();

      expect(primoVivo, isTrue);
      expect(secondoVivo, isTrue);

      await sub.cancel();
      await pump();

      // Senza questo, ogni apertura di una schermata lascerebbe dietro due
      // ascolti aperti: letture su Firestore pagate per nessuno.
      expect(primoVivo, isFalse);
      expect(secondoVivo, isFalse);

      await uno.close();
      await due.close();
    });
  });

  group('con tre flussi', () {
    test('ognuno dei tre resta ascoltato', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final visti = <int>[];
      final sub = combinaTre(
        a.stream,
        b.stream,
        c.stream,
        (int x, int y, int z) => x + y + z,
      ).listen(visti.add);

      a.add(1);
      b.add(10);
      c.add(100);
      await pump();

      a.add(2);
      await pump();
      b.add(20);
      await pump();
      c.add(200);
      await pump();

      expect(visti, [111, 112, 122, 222]);

      await sub.cancel();
      await a.close();
      await b.close();
      await c.close();
    });
  });
}

/// Lascia girare la coda degli eventi: i flussi consegnano in modo asincrono,
/// e senza questa attesa si guarderebbe la lista prima che ci sia finito dentro
/// qualcosa.
Future<void> pump() => Future<void>.delayed(Duration.zero);
