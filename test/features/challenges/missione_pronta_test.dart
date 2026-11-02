import 'dart:convert';
import 'dart:io';

import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/entities/missione_pronta.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tutte, anche quelle che compaiono solo nella stagione di Halloween.
const _tutte = [...MissionePronta.tutte, ...MissionePronta.diHalloween];

/// Le righe di un file di `functions/dati`: quello che finisce nel database.
List<Map<String, dynamic>> _righeDi(String file) {
  final testo = File('functions/dati/$file').readAsStringSync();

  return (jsonDecode(testo) as List).cast<Map<String, dynamic>>();
}

void main() {
  group('il catalogo che finisce nel database', () {
    final catalogo = _righeDi('missioni_pronte.json');

    test('passa tutto dalla validazione del modulo, riga per riga', () {
      // **Queste righe non passano dalla compilazione**: si cambiano toccando un
      // file, e l'app le legge dal database. Questa prova è l'unico momento in
      // cui qualcuno le guarda col filtro in mano prima che arrivino alla gente.
      for (final riga in catalogo) {
        final titolo = riga['titolo'] as String;

        expect(
          ChallengeDraftValidators.validateTitle(titolo),
          isNull,
          reason: 'titolo: $titolo',
        );
        expect(
          ChallengeDraftValidators.validateBrief(riga['consegna'] as String),
          isNull,
          reason: 'consegna: $titolo',
        );
      }
    });

    test('i titoli si leggono su una scheda, e non si ripetono', () {
      final titoli = {for (final riga in catalogo) riga['titolo'] as String};

      expect(titoli.length, catalogo.length);

      for (final titolo in titoli) {
        expect(titolo.length, lessThanOrEqualTo(44), reason: titolo);
      }
    });

    test("l'app capisce ogni riga", () {
      for (final riga in catalogo) {
        final titolo = riga['titolo'];

        expect(
          CategoriaMissione.fromName(riga['categoria'] as String?),
          isNotNull,
          reason: '$titolo',
        );
        expect(
          MediaKind.values.map((m) => m.name),
          contains(riga['media']),
          reason: '$titolo',
        );

        if (riga['source'] != null) {
          expect(
            ChallengeSource.values.map((s) => s.name),
            contains(riga['source']),
            reason: '$titolo',
          );
        }
      }
    });

    test('ne bastano per ore di aperture, di ogni tipo', () {
      // Dieci alla volta, ogni dieci minuti: duecento sono più di tre ore prima
      // di rivedere la stessa. E ogni tipo deve arrivare fino in fondo alla
      // fila, o le ultime dieci sarebbero tutte uguali.
      expect(catalogo.length, greaterThanOrEqualTo(200));

      for (final tipo in CategoriaMissione.values) {
        if (tipo == CategoriaMissione.halloween) {
          continue;
        }

        expect(
          catalogo.where((riga) => riga['categoria'] == tipo.name).length,
          greaterThanOrEqualTo(15),
          reason: tipo.name,
        );
      }
    });

    test('nessun video chiede più di quanto un video può durare', () {
      // Era successo: "un minuto di plank, in un video solo" stava nel menù con
      // i video fermi a venti secondi. Si toccava, si provava, e non si poteva.
      final troppo = RegExp(r'un minuto|minuti|trenta secondi|mezzo minuto');

      for (final riga in catalogo.where((r) => r['media'] == 'video')) {
        expect(
          troppo.hasMatch(riga['consegna'] as String),
          isFalse,
          reason: '${riga['titolo']}',
        );
      }
    });

    test('la maggior parte si fa adesso, non in archivio', () {
      final archivio = catalogo.where((r) => r['source'] == 'archive').length;

      expect(archivio * 2, lessThan(catalogo.length));
    });

    test('le scorte nel codice sono copie esatte del catalogo', () {
      // Sono il ripiego per quando il database non risponde: se si staccassero
      // dal file, un guasto riporterebbe in vita missioni tolte da tempo.
      final perTitolo = {for (final r in catalogo) r['titolo']: r};

      for (final scorta in MissionePronta.tutte) {
        final riga = perTitolo[scorta.titolo];

        expect(riga, isNotNull, reason: scorta.titolo);
        expect(riga!['consegna'], scorta.consegna, reason: scorta.titolo);
        expect(riga['categoria'], scorta.categoria.name, reason: scorta.titolo);
        expect(riga['media'], scorta.mediaKind.name, reason: scorta.titolo);
        expect(
          riga['source'] ?? ChallengeSource.instant.name,
          scorta.source.name,
          reason: scorta.titolo,
        );
      }
    });
  });

  group('le sfide del giorno', () {
    final sfide = _righeDi('sfide_del_giorno.json');

    test('coprono tutto novembre senza ripetersi', () {
      expect(sfide.length, greaterThanOrEqualTo(30));
      expect({for (final s in sfide) s['titolo']}.length, sfide.length);
    });

    test('passano tutte dal filtro', () {
      for (final sfida in sfide) {
        final titolo = sfida['titolo'] as String;

        expect(
          ChallengeDraftValidators.validateTitle(titolo),
          isNull,
          reason: titolo,
        );
        expect(
          ChallengeDraftValidators.validateBrief(sfida['consegna'] as String),
          isNull,
          reason: titolo,
        );
        expect(
          MediaKind.values.map((m) => m.name),
          contains(sfida['media']),
          reason: titolo,
        );
      }
    });

    test('non ci finisce nessuna hot', () {
      // Sono gratis, quindi niente conto Stripe: l'età resta quella dichiarata.
      // E le firma CRASY, con una notifica a tutti alle nove.
      final hot = {
        for (final riga in _righeDi('missioni_pronte.json'))
          if (riga['categoria'] == CategoriaMissione.hot.name)
            (riga['titolo'] as String).toLowerCase(),
      };

      for (final sfida in sfide) {
        final titolo = (sfida['titolo'] as String).toLowerCase();

        expect(hot.contains(titolo), isFalse, reason: titolo);
      }
    });
  });

  group('il giro di dieci', () {
    final mezzogiorno = DateTime.utc(2026, 11, 15, 12);

    int posto(DateTime quando, {String chi = 'anna', int totale = 240}) {
      return MissionePronta.postoDelGiro(
        chi: chi,
        quando: quando,
        totale: totale,
      );
    }

    test('dentro gli stessi dieci minuti resta fermo', () {
      expect(
        posto(mezzogiorno.add(const Duration(minutes: 9, seconds: 59))),
        posto(mezzogiorno),
      );
    });

    test('dopo dieci minuti avanza di dieci', () {
      expect(
        posto(mezzogiorno.add(MissionePronta.ogni)),
        (posto(mezzogiorno) + MissionePronta.quanteAllaVolta) % 240,
      );
    });

    test('prima di rivederne una, si vede tutto il catalogo', () {
      final viste = <int>{};

      for (var giro = 0; giro < 24; giro++) {
        final inizio = posto(mezzogiorno.add(MissionePronta.ogni * giro));

        for (var i = 0; i < MissionePronta.quanteAllaVolta; i++) {
          expect(viste.add((inizio + i) % 240), isTrue, reason: 'giro $giro');
        }
      }

      expect(viste.length, 240);
    });

    test('ognuno parte da un punto diverso', () {
      // Se tutti vedessero le stesse dieci si lancerebbe dieci volte la stessa
      // gara, e la home sarebbe una fila di doppioni.
      final partenze = {
        for (final chi in ['anna', 'bruno', 'carla', 'dario', 'elena'])
          posto(mezzogiorno, chi: chi),
      };

      expect(partenze.length, greaterThan(1));
    });

    test('sta sempre dentro il catalogo', () {
      for (final totale in [1, 7, 10, 239, 240]) {
        for (var giro = 0; giro < 50; giro++) {
          final inizio = posto(
            mezzogiorno.add(MissionePronta.ogni * giro),
            totale: totale,
          );

          expect(inizio, inInclusiveRange(0, totale - 1));
        }
      }
    });

    test('con un catalogo vuoto non esplode', () {
      expect(posto(mezzogiorno, totale: 0), 0);
    });

    test('a turno: apre una hot, e le prime tre sono diverse', () {
      MissionePronta una(String titolo, CategoriaMissione tipo) {
        return MissionePronta(titolo: titolo, consegna: 'x', categoria: tipo);
      }

      final fila = MissionePronta.aTurno([
        una('a', CategoriaMissione.pazza),
        una('b', CategoriaMissione.pazza),
        una('c', CategoriaMissione.abilita),
        una('d', CategoriaMissione.hot),
        una('e', CategoriaMissione.hot),
      ]);

      expect(fila.map((m) => m.titolo), ['d', 'c', 'a', 'e', 'b']);
    });
  });

  group('le missioni già scritte', () {
    test('passano tutte la validazione del modulo', () {
      // **È il controllo che vale più di tutti gli altri qui.** Una missione
      // pronta che non passa i controlli del modulo è peggio di nessuna
      // missione pronta: si tocca, i campi si riempiono da soli, e il tasto
      // per mandarla resta spento senza che si capisca perché.
      for (final pronta in _tutte) {
        expect(
          ChallengeDraftValidators.validateTitle(pronta.titolo),
          isNull,
          reason: 'titolo: ${pronta.titolo}',
        );

        expect(
          ChallengeDraftValidators.validateBrief(pronta.consegna),
          isNull,
          reason: 'consegna: ${pronta.titolo}',
        );
      }
    });

    test('nessuna si chiama come un\'altra', () {
      // Due righe identiche in una fila da sfogliare si leggono come un
      // difetto, e chi scorre si ferma a capire se ha già visto quella.
      final titoli = {for (final p in _tutte) p.titolo};

      expect(titoli.length, _tutte.length);
    });

    test('la maggior parte si fa adesso, non in archivio', () {
      // L'istantanea è quello che CRASY è. L'archivio esiste per le missioni
      // che altrimenti non si potrebbero fare — una foto di dieci anni fa non
      // si scatta — e se diventasse la norma nel menù, il menù direbbe che
      // CRASY è un'altra cosa.
      final adesso = MissionePronta.tutte
          .where((p) => p.source == ChallengeSource.instant)
          .length;

      expect(adesso * 2, greaterThan(MissionePronta.tutte.length));
    });

    test('ce ne sono abbastanza da far scorrere', () {
      // Con tre o quattro si legge come un elenco chiuso: si guardano tutte,
      // non piace nessuna, e si torna al foglio bianco con l'idea che non ci
      // sia altro.
      expect(MissionePronta.tutte.length, greaterThanOrEqualTo(8));
    });

    test("l'ordine cambia ogni giorno", () {
      // Le prime tre sono le uniche che si vedono senza scorrere: se sono
      // sempre quelle, le altre non le guarda nessuno, e chi lancia due volte
      // in una settimana si ritrova lo stesso menù.
      final oggi = MissionePronta.diOggi(DateTime(2026, 10, 11));
      final domani = MissionePronta.diOggi(DateTime(2026, 10, 12));

      expect(
        oggi.take(3).map((m) => m.titolo),
        isNot(domani.take(3).map((m) => m.titolo)),
      );
    });

    test("nello stesso giorno l'ordine non si muove", () {
      // La schermata si ridisegna a ogni lettera battuta nei campi: un ordine
      // che cambia sotto le dita e' la cosa piu' fastidiosa che possa fare.
      expect(
        MissionePronta.diOggi(DateTime(2026, 10, 11, 9)).map((m) => m.titolo),
        MissionePronta.diOggi(DateTime(2026, 10, 11, 23)).map((m) => m.titolo),
      );
    });

    test('non se ne perde nessuna rimescolando', () {
      // Un ordine nuovo, non un elenco nuovo: devono esserci tutte. A marzo
      // senza quelle di Halloween.
      final mescolate = MissionePronta.diOggi(DateTime(2026, 3, 11));

      expect(mescolate.length, MissionePronta.tutte.length);
      expect(
        mescolate.map((m) => m.titolo).toSet(),
        MissionePronta.tutte.map((m) => m.titolo).toSet(),
      );
    });

    test('a ottobre arrivano quelle di Halloween, e in testa', () {
      final ottobre = MissionePronta.diOggi(DateTime(2026, 10, 28));

      expect(ottobre.length, _tutte.length);
      expect(ottobre.first.categoria, CategoriaMissione.halloween);
      expect(
        MissionePronta.diOggi(
          DateTime(2026, 3, 11),
        ).where((m) => m.categoria == CategoriaMissione.halloween),
        isEmpty,
      );
    });

    test('le prime tre di ogni giorno sono di tipo diverso', () {
      // Sono le uniche che si vedono senza scorrere: una hot, un ricordo, una
      // sfida — non tre foto del frigo.
      for (var giorno = 1; giorno <= 60; giorno++) {
        final quando = DateTime(2026, 2, 1).add(Duration(days: giorno));
        final prime = MissionePronta.diOggi(quando).take(3);

        expect(
          prime.map((m) => m.categoria).toSet().length,
          3,
          reason: '$quando',
        );
      }
    });

    test('ci sono tutti i tipi, e nessuno fa da riempitivo', () {
      for (final tipo in CategoriaMissione.values) {
        expect(
          _tutte.where((m) => m.categoria == tipo).length,
          greaterThanOrEqualTo(4),
          reason: tipo.name,
        );
      }
    });

    test('i titoli si leggono senza aprire', () {
      // Il titolo è spesso l'unica cosa che si legge: se serve la consegna per
      // capire cosa c'è da fare, quella missione in una fila da sfogliare non
      // viene scelta mai.
      for (final pronta in _tutte) {
        expect(
          pronta.titolo.length,
          lessThanOrEqualTo(44),
          reason: 'troppo lungo per una scheda: ${pronta.titolo}',
        );
      }
    });
  });
}
