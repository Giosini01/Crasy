import 'dart:typed_data';

import 'package:app_incontri/features/daily/domain/entities/daily.dart';

abstract class DailyRepository {
  /// Daily pubblicate da [userId] nel giorno [dateKey] (`yyyy-MM-dd`).
  Stream<List<Daily>> watchDailiesForDay(String userId, String dateKey);

  /// Carica lo scatto su Storage e ne registra il documento su Firestore.
  ///
  /// Prende i byte e non un percorso di file perche' su web `XFile.path` e'
  /// un blob url che Storage non sa leggere.
  /// [vibe] e' l'identificativo dell'etichetta scelta, se l'utente ne ha
  /// scelta una: e' facoltativa e non blocca niente.
  Future<Daily> publishDaily({
    required String userId,
    required Uint8List bytes,
    required DateTime now,
    String? vibe,
  });
}
