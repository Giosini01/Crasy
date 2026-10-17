/// **Un file gia' salito su Storage, che un nuovo tentativo non rimanda.**
///
/// Una partecipazione si manda in due passi: prima sale il file, poi si
/// scrive il documento in gara. Con poca rete il secondo passo puo' fallire
/// quando il primo e' gia' riuscito — e senza questo, riprovando, un video da
/// venti megabyte ripartiva da zero per scrivere una riga.
///
/// Si tiene da parte appena il file e' salito, e il tentativo dopo riparte da
/// qui: resta da scrivere solo il documento.
class FileCaricato {
  const FileCaricato({
    required this.storagePath,
    required this.mediaUrl,
    this.thumbUrl = '',
  });

  /// Dove sta il file su Storage.
  final String storagePath;

  /// L'indirizzo da cui lo si scarica.
  final String mediaUrl;

  /// La miniatura, quando c'e' (solo le foto).
  final String thumbUrl;

  Map<String, String> toMap() => {
    'storagePath': storagePath,
    'mediaUrl': mediaUrl,
    'thumbUrl': thumbUrl,
  };

  /// Letto da una scheda salvata, o `null` se manca o e' rotto.
  static FileCaricato? fromMap(Object? dati) {
    if (dati is! Map) {
      return null;
    }

    final percorso = dati['storagePath'];
    final indirizzo = dati['mediaUrl'];

    if (percorso is! String ||
        percorso.isEmpty ||
        indirizzo is! String ||
        indirizzo.isEmpty) {
      return null;
    }

    final miniatura = dati['thumbUrl'];

    return FileCaricato(
      storagePath: percorso,
      mediaUrl: indirizzo,
      thumbUrl: miniatura is String ? miniatura : '',
    );
  }
}
