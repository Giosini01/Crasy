/// **Le regole del gioco, come le scrive il server in `config/gioco`.**
///
/// Sfide del giorno, traguardi e livelli non stanno nel codice dell'app: si
/// cambiano dal pannello, e l'app le legge da li'. Qui c'e' solo come si
/// leggono — con un ripiego per ogni campo, perche' un documento scritto male
/// non deve far cadere la schermata.
library;

/// Una sfida: del giorno o permanente, la forma e' la stessa.
class SfidaDefinita {
  const SfidaDefinita({
    required this.id,
    required this.titolo,
    required this.descrizione,
    required this.icona,
    required this.metrica,
    required this.obiettivo,
    required this.xp,
    this.gruppo = '',
    this.attiva = true,
  });

  factory SfidaDefinita.fromMap(Map<String, dynamic> dati) {
    return SfidaDefinita(
      id: dati['id'] as String? ?? '',
      gruppo: dati['gruppo'] as String? ?? '',
      titolo: dati['titolo'] as String? ?? '',
      descrizione: dati['descrizione'] as String? ?? '',
      icona: dati['icona'] as String? ?? 'stella',
      metrica: dati['metrica'] as String? ?? '',
      obiettivo: _intero(dati['obiettivo'], 1),
      xp: _intero(dati['xp'], 0),
      attiva: dati['attiva'] as bool? ?? true,
    );
  }

  final String id;
  final String gruppo;
  final String titolo;
  final String descrizione;

  /// Il nome di un'icona fra quelle che l'app sa disegnare: vedi
  /// `iconaDelGioco`.
  final String icona;

  /// Cosa conta: `foto`, `fiammeDate`, `fiammeRicevute`, `amici`,
  /// `commenti`, `vittorie`, `giorniGiocati`, `serieRecord`.
  final String metrica;
  final int obiettivo;
  final int xp;
  final bool attiva;
}

/// Un gradino della scala: da quanti XP si e' a quel livello.
class LivelloDefinito {
  const LivelloDefinito({
    required this.numero,
    required this.nome,
    required this.xp,
  });

  final int numero;
  final String nome;
  final int xp;
}

/// A che punto della scala si e' adesso.
class LivelloAttuale {
  const LivelloAttuale({
    required this.numero,
    required this.nome,
    required this.xpDa,
    required this.xpA,
    required this.progresso,
  });

  final int numero;
  final String nome;

  /// Da quanti XP parte questo livello.
  final int xpDa;

  /// Quanti XP servono per il prossimo. Nullo all'ultimo livello.
  final int? xpA;

  /// Quanto si e' avanti verso il prossimo, da 0 a 1.
  final double progresso;

  bool get ultimo => xpA == null;
}

class RegoleDelGioco {
  const RegoleDelGioco({
    required this.giornaliere,
    required this.permanenti,
    required this.livelli,
  });

  factory RegoleDelGioco.fromMap(Map<String, dynamic> dati) {
    final giorno = dati['giornaliere'];
    final elenco = giorno is Map ? giorno['elenco'] : null;
    final livelli = <LivelloDefinito>[];
    final grezzi = dati['livelli'];

    if (grezzi is List) {
      for (final (i, voce) in grezzi.indexed) {
        if (voce is Map) {
          livelli.add(
            LivelloDefinito(
              numero: i + 1,
              nome: voce['nome'] as String? ?? 'Livello ${i + 1}',
              xp: _intero(voce['xp'], 0),
            ),
          );
        }
      }
    }

    return RegoleDelGioco(
      giornaliere: _sfide(elenco),
      permanenti: _sfide(dati['permanenti']),
      livelli: livelli.isEmpty
          ? const [LivelloDefinito(numero: 1, nome: 'Novizio', xp: 0)]
          : livelli,
    );
  }

  final List<SfidaDefinita> giornaliere;
  final List<SfidaDefinita> permanenti;
  final List<LivelloDefinito> livelli;

  SfidaDefinita? giornaliera(String id) {
    for (final sfida in giornaliere) {
      if (sfida.id == id) {
        return sfida;
      }
    }

    return null;
  }

  /// Il livello per una quantita' di XP: la stessa regola del server
  /// (`livelloDi` in `functions/gioco_regole.js`).
  LivelloAttuale livelloPer(int xp) {
    var attuale = livelli.first;

    for (final livello in livelli) {
      if (xp >= livello.xp) {
        attuale = livello;
      }
    }

    LivelloDefinito? prossimo;

    for (final livello in livelli) {
      if (livello.numero == attuale.numero + 1) {
        prossimo = livello;
      }
    }

    return LivelloAttuale(
      numero: attuale.numero,
      nome: attuale.nome,
      xpDa: attuale.xp,
      xpA: prossimo?.xp,
      progresso: prossimo == null
          ? 1
          : ((xp - attuale.xp) / (prossimo.xp - attuale.xp)).clamp(0.0, 1.0),
    );
  }

  /// Il nome di un livello, per numero.
  String nomeDelLivello(int numero) {
    for (final livello in livelli) {
      if (livello.numero == numero) {
        return livello.nome;
      }
    }

    return 'Livello $numero';
  }
}

List<SfidaDefinita> _sfide(Object? grezze) {
  if (grezze is! List) {
    return const [];
  }

  return [
    for (final voce in grezze)
      if (voce is Map) SfidaDefinita.fromMap(Map<String, dynamic>.from(voce)),
  ].where((sfida) => sfida.id.isNotEmpty && sfida.attiva).toList();
}

int _intero(Object? valore, int ripiego) =>
    valore is num ? valore.toInt() : ripiego;
