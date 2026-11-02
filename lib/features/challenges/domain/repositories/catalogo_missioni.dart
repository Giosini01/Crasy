import 'package:crasy/features/challenges/domain/entities/missione_pronta.dart';

/// **Dove stanno le missioni già scritte.**
///
/// Sono in fila, ognuna al suo posto: chi le chiede dice da dove cominciare e
/// quante ne vuole, e non deve leggere tutto il catalogo per mostrarne dieci.
abstract interface class CatalogoMissioni {
  /// Quante ce ne sono in tutto.
  Future<int> quante();

  /// [quante] missioni a partire da [posto]. Arrivato in fondo, ricomincia da
  /// capo: chi capita a fine fila non ne deve vedere solo due.
  Future<List<MissionePronta>> daPosto(int posto, int quante);
}
