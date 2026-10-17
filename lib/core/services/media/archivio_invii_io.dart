import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crasy/core/services/media/archivio_invii.dart';
import 'package:path_provider/path_provider.dart';

/// Sul telefono, una cartella. Vedi [ArchivioInvii].
ArchivioInvii creaArchivioInvii() => ArchivioInviiSulDisco();

/// **Dove aspettano gli scatti che non sono ancora arrivati.**
///
/// Una cartella nostra, nella memoria dell'app che il sistema non svuota: ci
/// stanno lo scatto e la sua scheda, e restano li' — anche se l'app si chiude
/// — finche' non sono in gara o finche' la gara non li puo' piu' accettare.
/// Vedi `InvioInAttesa`.
class ArchivioInviiSulDisco implements ArchivioInvii {
  Directory? _cartella;

  Future<Directory> _dove() async {
    final gia = _cartella;

    if (gia != null) {
      return gia;
    }

    final casa = await getApplicationSupportDirectory();
    final cartella = Directory(
      '${casa.path}${Platform.pathSeparator}invii_in_attesa',
    );

    if (!cartella.existsSync()) {
      await cartella.create(recursive: true);
    }

    return _cartella = cartella;
  }

  Future<String> _percorso(String nome) async =>
      '${(await _dove()).path}${Platform.pathSeparator}$nome';

  /// Tiene i byte di una foto. Torna dove li ha messi.
  @override
  Future<String> tieniIByte(
    String id,
    Uint8List byte,
    String estensione,
  ) async {
    final file = File(await _percorso('$id.$estensione'));

    await file.writeAsBytes(byte, flush: true);

    return file.path;
  }

  /// Tiene un file che sta gia' sul disco — un video — **spostandolo**, non
  /// copiandolo: decine di megabyte che non passano due volte per la memoria
  /// del telefono.
  @override
  Future<String> tieniIlFile(
    String id,
    String percorso,
    String estensione,
  ) async {
    final origine = File(percorso);
    final destinazione = await _percorso('$id.$estensione');

    try {
      return (await origine.rename(destinazione)).path;
    } on FileSystemException {
      // Su un altro disco non si sposta: si copia, e l'originale si butta.
      final copia = await origine.copy(destinazione);

      try {
        await origine.delete();
      } on Object catch (_) {
        // Una copia di troppo e' meno grave di uno scatto perso.
      }

      return copia.path;
    }
  }

  /// I byte di uno scatto tenuto da parte.
  @override
  Future<Uint8List> leggi(String percorso) => File(percorso).readAsBytes();

  /// Se lo scatto c'e' ancora, e non e' vuoto.
  @override
  bool esiste(String percorso) {
    if (percorso.isEmpty) {
      return false;
    }

    try {
      final file = File(percorso);

      return file.existsSync() && file.lengthSync() > 0;
    } on Object catch (_) {
      return false;
    }
  }

  /// Scrive la scheda di un invio, **tutta o niente**: prima su un file a
  /// parte, poi al suo posto con un solo gesto. Un'app chiusa a meta'
  /// scrittura non lascia una scheda rotta.
  @override
  Future<void> salvaLaScheda(String id, Map<String, Object?> scheda) async {
    final file = File(await _percorso('$id.json'));
    final provvisorio = File('${file.path}.tmp');

    await provvisorio.writeAsString(jsonEncode(scheda), flush: true);
    await provvisorio.rename(file.path);
  }

  /// Tutte le schede salvate, cosi' come sono.
  @override
  Future<List<Object?>> leggiLeSchede() async {
    final cartella = await _dove();
    final schede = <Object?>[];

    await for (final voce in cartella.list()) {
      if (voce is! File || !voce.path.endsWith('.json')) {
        continue;
      }

      try {
        schede.add(jsonDecode(await voce.readAsString()));
      } on Object catch (_) {
        // Una scheda che non si legge non deve fermare le altre.
      }
    }

    return schede;
  }

  /// Butta scheda e scatto: l'invio e' finito, in un modo o nell'altro.
  @override
  Future<void> butta(String id, String file) async {
    for (final percorso in [await _percorso('$id.json'), file]) {
      if (percorso.isEmpty) {
        continue;
      }

      try {
        final voce = File(percorso);

        if (voce.existsSync()) {
          await voce.delete();
        }
      } on Object catch (_) {
        // Un file rimasto e' molto meno grave di un invio rifatto.
      }
    }
  }
}
