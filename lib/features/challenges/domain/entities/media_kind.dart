/// Cosa chiede una challenge: una foto o un video.
///
/// E' un **vincolo**, non un suggerimento. Una gara in cui qualcuno manda una
/// foto e qualcun altro un video non e' una gara: sono due cose che non si
/// possono mettere in fila e confrontare, e alla fine si pagherebbe un premio
/// scegliendo fra mele e pere.
///
/// In tutti e due i casi vale la stessa regola di sempre: **si registra sul
/// momento**. Un video pescato dalla galleria e' esattamente il problema che si
/// voleva evitare con le foto, moltiplicato — un video montato in casa batte
/// qualunque cosa girata in trenta secondi per strada.
enum MediaKind {
  photo('FOTO', 'una foto', 'Scatta ora'),
  video('VIDEO', 'un video', 'Registra ora');

  const MediaKind(this.label, this.article, this.action);

  /// Come si chiama nell'interfaccia: `FOTO`, `VIDEO`.
  final String label;

  /// Come la si nomina dentro una frase: "manda **una foto**".
  final String article;

  /// L'etichetta del comando che apre la fotocamera.
  final String action;

  bool get isVideo => this == MediaKind.video;

  /// Quanto puo' durare un video.
  ///
  /// Venti secondi e non di piu'. Le gare si guardano tutte di fila, scorrendo:
  /// un video lungo non lo finisce nessuno, e uno che nessuno finisce non
  /// prende fiamme — il limite protegge chi lo manda prima ancora di chi lo
  /// guarda.
  ///
  /// Era mezzo minuto, e trenta secondi dalla galleria sono decine di megabyte
  /// da caricare su una rete che spesso non e' il wifi di casa: il limite che
  /// si vedeva non era questo, era l'attesa.
  static const Duration maxVideoDuration = Duration(seconds: 20);

  static MediaKind fromName(String? value) {
    for (final kind in MediaKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }

    // Le challenge scritte prima che questo campo esistesse chiedevano una
    // foto: trattarle diversamente cambierebbe le regole a gara in corso.
    return MediaKind.photo;
  }
}
