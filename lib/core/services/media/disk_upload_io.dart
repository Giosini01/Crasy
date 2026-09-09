import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

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
) async {
  final file = File(percorso);

  // **Un file vuoto non diventa una partecipazione.**
  //
  // E' successo: il video della fotocamera spariva prima dell'invio, il
  // caricamento riusciva lo stesso, e in gara finiva un file da zero byte —
  // un riquadro grigio che nessun lettore al mondo puo' aprire, e nessun errore
  // da nessuna parte. Chi l'aveva mandato credeva di essere in gara.
  //
  // Meglio un invio che fallisce dicendolo, che uno che riesce senza contenuto.
  if (!file.existsSync() || file.lengthSync() == 0) {
    throw const FileSystemException(
      "Il file da mandare non c'è più. Riprova a registrare.",
    );
  }

  await riferimento.putFile(file, dati);
}

/// Porta il video appena registrato in una cartella **nostra**.
///
/// ## Perche' esiste, e cosa e' costato non averla
///
/// La fotocamera scrive il video in una cartella temporanea del sistema, e
/// quel file **non e' nostro**: appena la schermata della fotocamera si chiude
/// e il suo controllore viene smontato, il sistema se lo riprende. Finche' i
/// byte si leggevano subito — un istante dopo lo scatto — non si notava.
///
/// Poi il caricamento e' passato a leggere **dal disco**, per non tenere decine
/// di megabyte in memoria e non far chiudere l'app. Giusto, ma con un effetto
/// che nessuno aveva previsto: fra la registrazione e l'invio passa tutto il
/// tempo dell'anteprima, e in quel tempo il file spariva. Il caricamento
/// riusciva lo stesso e metteva in gara **un file da zero byte**: una
/// partecipazione che non si vede, e nessun errore da nessuna parte.
///
/// Da qui in poi il file e' in una cartella nostra, che nessuno pulisce, e
/// resta li' finche' non lo cancelliamo noi.
///
/// **E la lunghezza si controlla subito.** Un file vuoto qui diventa un errore
/// che si legge a schermo, non una partecipazione fantasma scoperta il giorno
/// dopo.
Future<String> mettiAlSicuro(String origine) async {
  final venuto = File(origine);

  if (!venuto.existsSync() || venuto.lengthSync() == 0) {
    throw const FileSystemException("Il video registrato non c'è più.");
  }

  final casa = await getApplicationSupportDirectory();
  final nome = 'crasy-${DateTime.now().microsecondsSinceEpoch}'
      '${origine.contains('.') ? origine.substring(origine.lastIndexOf('.')) : '.mp4'}';
  final salvo = File('${casa.path}${Platform.pathSeparator}$nome');

  // `copy` lo fa il sistema operativo, a pezzi: non passa dalla memoria, che e'
  // tutto il motivo per cui si era smesso di leggere i byte.
  await venuto.copy(salvo.path);

  if (salvo.lengthSync() == 0) {
    throw const FileSystemException("La copia del video è vuota.");
  }

  return salvo.path;
}

/// Butta la copia, a cose fatte.
///
/// Senza, ogni video registrato resterebbe sul telefono per sempre: qualche
/// decina di megabyte alla volta, in una cartella che nessuno guarda.
Future<void> buttaLaCopia(String percorso) async {
  if (percorso.isEmpty) {
    return;
  }

  try {
    final file = File(percorso);

    if (file.existsSync()) {
      await file.delete();
    }
  } on Object catch (_) {
    // Un file rimasto e' molto meno grave di un invio fallito per la pulizia.
  }
}
