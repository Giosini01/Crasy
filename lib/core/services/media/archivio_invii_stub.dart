import 'dart:typed_data';

import 'package:crasy/core/services/media/archivio_invii.dart';

/// Sul web, la memoria. Vedi [ArchivioInvii].
ArchivioInvii creaArchivioInvii() => ArchivioInviiInMemoria();

/// **Sul web gli scatti in attesa stanno in memoria.**
///
/// Il browser non da' una cartella in cui tenerli: restano finche' resta aperta
/// la scheda. Riprovare quando la rete torna funziona lo stesso; ripartire dopo
/// aver chiuso il browser no, ed e' un limite del web, non una svista.
class ArchivioInviiInMemoria implements ArchivioInvii {
  final Map<String, Uint8List> _byte = {};

  static const String _prefisso = 'memoria:';

  @override
  Future<String> tieniIByte(
    String id,
    Uint8List byte,
    String estensione,
  ) async {
    _byte[id] = byte;

    return '$_prefisso$id';
  }

  /// Sul web i video arrivano gia' come byte: non c'e' nessun file da tenere.
  @override
  Future<String> tieniIlFile(String id, String percorso, String estensione) =>
      throw UnsupportedError('Sul web non ci sono file su disco.');

  @override
  Future<Uint8List> leggi(String percorso) async =>
      _byte[percorso.replaceFirst(_prefisso, '')] ?? Uint8List(0);

  @override
  bool esiste(String percorso) =>
      _byte[percorso.replaceFirst(_prefisso, '')]?.isNotEmpty ?? false;

  /// Non si salva niente: vedi sopra.
  @override
  Future<void> salvaLaScheda(String id, Map<String, Object?> scheda) async {}

  @override
  Future<List<Object?>> leggiLeSchede() async => const [];

  @override
  Future<void> butta(String id, String file) async {
    _byte.remove(id);
  }
}
