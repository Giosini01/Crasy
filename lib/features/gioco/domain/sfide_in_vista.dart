import 'package:crasy/features/gioco/domain/entities/regole_del_gioco.dart';
import 'package:crasy/features/gioco/domain/entities/stato_del_gioco.dart';

/// Come sta una sfida, detto in quattro parole.
enum StatoSfida {
  /// Non ancora cominciata.
  daFare,

  /// Cominciata e non finita.
  inCorso,

  /// Fatta: i suoi XP sono gia' arrivati.
  completata,

  /// **Un traguardo che viene dopo un altro**: "Fotografo" si apre quando
  /// "Primi scatti" e' fatto. Il conto va avanti lo stesso — le foto sono
  /// foto — ma il traguardo si guarda quando tocca a lui.
  bloccata,
}

/// Una sfida pronta da mostrare: cosa chiede, a che punto si e', come sta.
class SfidaInVista {
  const SfidaInVista({
    required this.sfida,
    required this.progresso,
    required this.stato,
  });

  final SfidaDefinita sfida;

  /// A che punto si e', mai oltre l'obiettivo: "7/5" non dice niente di piu'
  /// di "5/5", e sembra un errore.
  final int progresso;
  final StatoSfida stato;

  double get frazione =>
      sfida.obiettivo <= 0 ? 1 : (progresso / sfida.obiettivo).clamp(0.0, 1.0);
}

/// **Le sfide di oggi**, nell'ordine in cui le ha scelte il server.
///
/// Una sfida tolta dal pannello a meta' giornata non si mostra: il server non
/// la puo' piu' dare, e una card che non si potra' mai fare e' peggio di una
/// card in meno.
List<SfidaInVista> sfideDiOggi(RegoleDelGioco regole, StatoDelGioco stato) {
  final elenco = <SfidaInVista>[];

  for (final id in stato.scelteDiOggi) {
    final sfida = regole.giornaliera(id);

    if (sfida == null) {
      continue;
    }

    final fatta = stato.completateOggi.contains(id);
    final conto = stato.contatoriDiOggi[sfida.metrica] ?? 0;

    elenco.add(
      SfidaInVista(
        sfida: sfida,
        progresso: fatta ? sfida.obiettivo : conto.clamp(0, sfida.obiettivo),
        stato: fatta
            ? StatoSfida.completata
            : conto > 0
            ? StatoSfida.inCorso
            : StatoSfida.daFare,
      ),
    );
  }

  return elenco;
}

/// **I traguardi**, prima quelli su cui si sta lavorando, poi quelli che
/// aspettano il loro turno, in fondo quelli fatti.
///
/// Fra i traguardi della stessa cosa — 10, 50, 100 foto — conta solo il primo
/// non ancora fatto: gli altri sono `bloccata`. Mostrarli tutti "in corso"
/// direbbe che si sta andando verso cento foto quando se ne sono mandate tre.
List<SfidaInVista> traguardi(RegoleDelGioco regole, StatoDelGioco stato) {
  final primoAperto = <String, int>{};

  for (final sfida in regole.permanenti) {
    if (stato.completate.contains(sfida.id)) {
      continue;
    }

    final gia = primoAperto[sfida.metrica];

    if (gia == null || sfida.obiettivo < gia) {
      primoAperto[sfida.metrica] = sfida.obiettivo;
    }
  }

  final elenco = <SfidaInVista>[];

  for (final sfida in regole.permanenti) {
    final fatta = stato.completate.contains(sfida.id);
    final conto = stato.contatori[sfida.metrica] ?? 0;
    final tocca = primoAperto[sfida.metrica] == sfida.obiettivo;

    elenco.add(
      SfidaInVista(
        sfida: sfida,
        progresso: fatta ? sfida.obiettivo : conto.clamp(0, sfida.obiettivo),
        stato: fatta
            ? StatoSfida.completata
            : !tocca
            ? StatoSfida.bloccata
            : conto > 0
            ? StatoSfida.inCorso
            : StatoSfida.daFare,
      ),
    );
  }

  int peso(StatoSfida stato) => switch (stato) {
    StatoSfida.inCorso => 0,
    StatoSfida.daFare => 1,
    StatoSfida.bloccata => 2,
    StatoSfida.completata => 3,
  };

  // `sort` non e' stabile: l'indice tiene l'ordine del pannello a parita'.
  final indicizzate = elenco.indexed.toList()
    ..sort((a, b) {
      final differenza = peso(a.$2.stato) - peso(b.$2.stato);

      return differenza != 0 ? differenza : a.$1 - b.$1;
    });

  return [for (final (_, voce) in indicizzate) voce];
}
