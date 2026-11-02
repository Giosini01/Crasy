import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/entities/missione_pronta.dart';
import 'package:crasy/features/challenges/domain/repositories/catalogo_missioni.dart';

/// **Il catalogo su Firestore**, in `missioniPronte`.
///
/// Lo scrive `functions/tool/menu_missioni.js` a partire da
/// `functions/dati/missioni_pronte.json`, e dai telefoni si legge soltanto.
///
/// **Si leggono le dieci che servono, non tutte.** Ogni documento letto si
/// paga, e il catalogo sono centinaia di righe: aprire la schermata di creazione
/// costa undici letture invece di duecentoquaranta.
class FirestoreCatalogoMissioni implements CatalogoMissioni {
  const FirestoreCatalogoMissioni(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _catalogo =>
      _firestore.collection('missioniPronte');

  @override
  Future<int> quante() async {
    final conto = await _catalogo.count().get();

    return conto.count ?? 0;
  }

  @override
  Future<List<MissionePronta>> daPosto(int posto, int quante) async {
    final inFila = _catalogo.orderBy('ordine');
    final prime = await inFila.startAt([posto]).limit(quante).get();
    final documenti = [...prime.docs];

    if (documenti.length < quante) {
      final daCapo = await inFila.limit(quante - documenti.length).get();
      final gia = {for (final documento in documenti) documento.id};

      // Con un catalogo piu' corto di dieci, ricominciare da capo ripesca le
      // stesse: due schede uguali in fila si leggono come un difetto.
      documenti.addAll(daCapo.docs.where((d) => !gia.contains(d.id)));
    }

    return documenti.map((d) => _missione(d.data())).nonNulls.toList();
  }

  /// Una riga del catalogo, o `null` se non si puo' mostrare.
  ///
  /// **Una riga scritta male si salta**, e non fa fallire le altre nove.
  MissionePronta? _missione(Map<String, dynamic> dati) {
    final titolo = dati['titolo'];
    final consegna = dati['consegna'];
    final categoria = CategoriaMissione.fromName(dati['categoria'] as String?);

    if (titolo is! String || consegna is! String || categoria == null) {
      return null;
    }

    return MissionePronta(
      titolo: titolo,
      consegna: consegna,
      categoria: categoria,
      mediaKind: MediaKind.fromName(dati['mediaKind'] as String?),
      source: ChallengeSource.fromName(dati['source'] as String?),
    );
  }
}
