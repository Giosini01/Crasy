import 'dart:typed_data';

/// **Dove aspettano gli scatti che non sono ancora arrivati.**
///
/// Sul telefono e' una cartella nostra, che il sistema non svuota: lo scatto e
/// la sua scheda restano li' — anche se l'app si chiude — finche' non sono in
/// gara o finche' la gara non li puo' piu' accettare. Sul web e' la memoria
/// della scheda del browser. Vedi `InvioInAttesa`.
abstract class ArchivioInvii {
  /// Tiene i byte di una foto. Torna dove li ha messi.
  Future<String> tieniIByte(String id, Uint8List byte, String estensione);

  /// Tiene un file che sta gia' sul disco — un video — spostandolo.
  Future<String> tieniIlFile(String id, String percorso, String estensione);

  /// I byte di uno scatto tenuto da parte.
  Future<Uint8List> leggi(String percorso);

  /// Se lo scatto c'e' ancora, e non e' vuoto.
  bool esiste(String percorso);

  /// Scrive la scheda di un invio.
  Future<void> salvaLaScheda(String id, Map<String, Object?> scheda);

  /// Tutte le schede salvate, cosi' come sono.
  Future<List<Object?>> leggiLeSchede();

  /// Butta scheda e scatto: l'invio e' finito, in un modo o nell'altro.
  Future<void> butta(String id, String file);
}
