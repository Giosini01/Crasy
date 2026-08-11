class Daily {
  const Daily({
    required this.id,
    required this.userId,
    required this.storagePath,
    required this.dateKey,
    required this.status,
    this.slot,
    this.capturedAt,
    this.downloadUrl,
    this.vibe,
  });

  final String id;
  final String userId;

  /// Percorso del file su Firebase Storage.
  final String storagePath;

  /// Giorno di appartenenza in formato `yyyy-MM-dd`, usato per contare quante
  /// Daily sono gia' state pubblicate oggi.
  final String dateKey;

  final DailyStatus status;

  /// Fascia oraria in cui e' stata scattata. Nulla per le istantanee create
  /// prima che le fasce esistessero.
  final int? slot;

  /// Istante dello scatto. Nullo finche' il server non ha risolto il proprio
  /// timestamp, come per i campi analoghi del profilo.
  final DateTime? capturedAt;

  /// URL pubblico della foto, risolto al momento della pubblicazione.
  final String? downloadUrl;

  /// Identificativo dell'etichetta scelta al momento dello scatto, se c'e'.
  final String? vibe;

  /// Verificata e distribuita.
  bool get isActive => status == DailyStatus.active;

  /// Caricata ma non ancora controllata dal server.
  bool get isPending => status == DailyStatus.draft;

  /// Scartata perche' non ritraeva una persona.
  bool get isRejected => status == DailyStatus.rejected;
}

enum DailyStatus {
  /// In attesa del controllo del server. E' lo stato con cui nasce ogni
  /// Daily: finche' non e' verificata non entra nel feed di nessuno.
  draft,

  active,

  /// Il controllo non ha riconosciuto una persona nella foto.
  rejected,

  expired,
}
