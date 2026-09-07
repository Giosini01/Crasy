import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Su telefono il file c'e', e si legge **a pezzi**.
///
/// E' l'unica differenza che conta fra questo e `putData`, e vale una
/// partecipazione: `putFile` non ha mai in mano piu' di un pezzo per volta,
/// quindi la memoria che serve non dipende da quanto e' lungo il video. Con i
/// byte, invece, un video di trenta secondi stava tutto in memoria — due volte,
/// contando la copia di chi lo spedisce — e il telefono poteva rifiutarsi di
/// darla: l'app chiusa di colpo, con dentro lo scatto di qualcuno.
const bool caricamentoDaDiscoDisponibile = true;

Future<void> caricaDalDisco(
  Reference riferimento,
  String percorso,
  SettableMetadata dati,
) => riferimento.putFile(File(percorso), dati);
