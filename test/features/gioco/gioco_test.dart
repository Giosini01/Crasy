import 'dart:convert';
import 'dart:io';

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/gioco/domain/entities/regole_del_gioco.dart';
import 'package:crasy/features/gioco/domain/entities/stato_del_gioco.dart';
import 'package:crasy/features/gioco/domain/sfide_in_vista.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Il gioco visto dall'app.** Le regole sono le stesse che il server scrive
/// in `config/gioco` all'inizio: si leggono dal file del server, cosi' se una
/// soglia cambia la, questi test la vedono.
void main() {
  final regole = RegoleDelGioco.fromMap(
    jsonDecode(File('functions/dati/gioco.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  group('i livelli', () {
    test('la stessa scala del server', () {
      // Gli stessi numeri di `livelloDi` in functions/test/gioco.test.js.
      final zero = regole.livelloPer(0);

      expect(zero.numero, 1);
      expect(zero.nome, 'Novizio');
      expect(zero.xpA, 100);
      expect(zero.progresso, 0);

      final meta = regole.livelloPer(150);

      expect(meta.numero, 2);
      expect(meta.progresso, 0.25);

      final cima = regole.livelloPer(99999);

      expect(cima.nome, 'Leggenda');
      expect(cima.ultimo, isTrue);
      expect(cima.progresso, 1);
    });

    test('il nome di un livello per numero', () {
      expect(regole.nomeDelLivello(3), 'Attivo');
      expect(regole.nomeDelLivello(42), 'Livello 42');
    });
  });

  group('le sfide di oggi', () {
    test('da fare, in corso, fatta: come le ha scelte il server', () {
      final stato = StatoDelGioco.fromMap({
        'xp': 20,
        'giorno': '2026-12-02',
        'oggi': {
          'scelte': ['prima_foto', 'social', 'nuovo_amico', 'sparita'],
          'contatori': {'foto': 1, 'fiammeDate': 2},
          'completate': {'prima_foto': 1},
        },
      });

      final oggi = sfideDiOggi(regole, stato);

      // Quella tolta dal pannello a meta' giornata non si mostra.
      expect(oggi.map((s) => s.sfida.id), [
        'prima_foto',
        'social',
        'nuovo_amico',
      ]);
      expect(oggi.map((s) => s.stato), [
        StatoSfida.completata,
        StatoSfida.inCorso,
        StatoSfida.daFare,
      ]);
      expect(oggi[1].progresso, 2);
      expect(oggi[1].frazione, 0.4);
    });

    test('il progresso non va mai oltre l obiettivo', () {
      final stato = StatoDelGioco.fromMap({
        'oggi': {
          'scelte': ['social'],
          'contatori': {'fiammeDate': 12},
          'completate': <String, Object>{},
        },
      });

      expect(sfideDiOggi(regole, stato).single.progresso, 5);
    });
  });

  group('i traguardi', () {
    test('si sblocca solo il primo non fatto di ogni cosa', () {
      final stato = StatoDelGioco.fromMap({
        'contatori': {'foto': 12, 'vittorie': 0},
        'completate': {'primi_scatti': 1},
      });

      final elenco = traguardi(regole, stato);
      final per = {for (final voce in elenco) voce.sfida.id: voce};

      expect(per['primi_scatti']!.stato, StatoSfida.completata);
      expect(per['fotografo']!.stato, StatoSfida.inCorso);
      expect(per['fotografo']!.progresso, 12);
      expect(per['collezionista']!.stato, StatoSfida.bloccata);
      expect(per['prima_vittoria']!.stato, StatoSfida.daFare);
      expect(per['campione']!.stato, StatoSfida.bloccata);

      // Prima quelli su cui si lavora, in fondo quelli fatti.
      expect(elenco.first.stato, StatoSfida.inCorso);
      expect(elenco.last.stato, StatoSfida.completata);
    });
  });

  test('uno stato mai scritto e un premio si leggono senza rompersi', () {
    final vuoto = StatoDelGioco.fromMap(const {});

    expect(vuoto.xp, 0);
    expect(vuoto.livello, 1);
    expect(vuoto.scelteDiOggi, isEmpty);

    final premio = PremioXp.fromMap('p_fotografo', {
      'titolo': 'Fotografo',
      'xp': 150,
      'tipo': 'permanente',
      'livelloDopo': 3,
    });

    expect(premio.permanente, isTrue);
    expect(premio.xp, 150);
    expect(premio.livelloDopo, 3);
  });

  test('la notifica del livello nuovo apre le sfide', () {
    final dove = pushTapOf({'kind': 'livello'}, daFermo: true);

    expect(dove.scheda, AppRoutes.profile);
    expect(dove.apri, AppRoutes.sfide);
  });
}
