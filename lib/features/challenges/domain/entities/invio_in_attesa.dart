import 'package:crasy/features/challenges/domain/entities/file_caricato.dart';
import 'package:crasy/features/challenges/domain/entities/ritaglio.dart';

/// A che punto e' un invio.
enum StatoInvio {
  /// Sta salendo adesso.
  inViaggio,

  /// Non e' riuscito per la rete: riprova da solo fra poco.
  inPausa,
}

/// **Una partecipazione mandata e non ancora arrivata.**
///
/// Prima una foto o un video esistevano solo dentro la pagina da cui si
/// mandavano: se la rete cedeva, o si usciva dalla pagina, o si chiudeva l'app
/// a meta' del caricamento, lo scatto era perso — e con poca rete succedeva
/// spesso, proprio con i video, che sono i piu' lunghi da mandare.
///
/// Adesso, premuto INVIA, lo scatto viene **salvato sul telefono** insieme a
/// questa scheda, e parte da li'. Se non arriva, riparte da solo appena puo':
/// anche dopo aver chiuso e riaperto l'app. Si butta solo quando e' in gara, o
/// quando la gara non lo puo' piu' accettare.
class InvioInAttesa {
  const InvioInAttesa({
    required this.id,
    required this.challengeId,
    required this.challengeTitle,
    required this.userId,
    required this.authorName,
    required this.isVideo,
    required this.contentType,
    required this.file,
    required this.creato,
    this.caption = '',
    this.muted = false,
    this.ritaglio,
    this.daily = false,
    this.tentativi = 0,
    this.caricato,
    this.stato = StatoInvio.inPausa,
    this.avanzamento = 0,
  });

  final String id;
  final String challengeId;

  /// Per dirlo a chi aspetta: "la tua foto per *titolo* e' in gara".
  final String challengeTitle;

  /// Di chi e': si manda solo con quella persona collegata.
  final String userId;
  final String authorName;

  final bool isVideo;
  final String contentType;

  /// Dove sta lo scatto sul telefono. Vedi `ArchivioInvii`.
  final String file;

  final DateTime creato;
  final String caption;
  final bool muted;
  final Ritaglio? ritaglio;

  /// Sfida del giorno o sfida mirata: non consuma una delle partecipazioni
  /// del giorno.
  final bool daily;

  /// Quante volte e' gia' stato provato.
  final int tentativi;

  /// Il file gia' salito, se un tentativo e' arrivato fin li': il prossimo
  /// scrive solo la partecipazione.
  final FileCaricato? caricato;

  /// Non si salva: a ogni avvio un invio riparte "in pausa".
  final StatoInvio stato;

  /// Quanto e' salito, da 0 a 1. Non si salva.
  final double avanzamento;

  InvioInAttesa copyWith({
    int? tentativi,
    FileCaricato? caricato,
    StatoInvio? stato,
    double? avanzamento,
  }) {
    return InvioInAttesa(
      id: id,
      challengeId: challengeId,
      challengeTitle: challengeTitle,
      userId: userId,
      authorName: authorName,
      isVideo: isVideo,
      contentType: contentType,
      file: file,
      creato: creato,
      caption: caption,
      muted: muted,
      ritaglio: ritaglio,
      daily: daily,
      tentativi: tentativi ?? this.tentativi,
      caricato: caricato ?? this.caricato,
      stato: stato ?? this.stato,
      avanzamento: avanzamento ?? this.avanzamento,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'challengeId': challengeId,
    'challengeTitle': challengeTitle,
    'userId': userId,
    'authorName': authorName,
    'isVideo': isVideo,
    'contentType': contentType,
    'file': file,
    'creato': creato.toIso8601String(),
    'caption': caption,
    'muted': muted,
    if (ritaglio != null) 'ritaglio': ritaglio!.toMap(),
    'daily': daily,
    'tentativi': tentativi,
    if (caricato != null) 'caricato': caricato!.toMap(),
  };

  /// Letta da una scheda salvata, o `null` se e' rotta: una scheda che non si
  /// sa leggere non deve bloccare le altre.
  static InvioInAttesa? fromJson(Object? dati) {
    if (dati is! Map) {
      return null;
    }

    String testo(String campo) {
      final valore = dati[campo];

      return valore is String ? valore : '';
    }

    final id = testo('id');
    final challengeId = testo('challengeId');
    final userId = testo('userId');
    final creato = DateTime.tryParse(testo('creato'));

    if (id.isEmpty || challengeId.isEmpty || userId.isEmpty || creato == null) {
      return null;
    }

    final tentativi = dati['tentativi'];

    return InvioInAttesa(
      id: id,
      challengeId: challengeId,
      challengeTitle: testo('challengeTitle'),
      userId: userId,
      authorName: testo('authorName'),
      isVideo: dati['isVideo'] == true,
      contentType: testo('contentType'),
      file: testo('file'),
      creato: creato,
      caption: testo('caption'),
      muted: dati['muted'] == true,
      ritaglio: Ritaglio.fromMap(dati['ritaglio']),
      daily: dati['daily'] == true,
      tentativi: tentativi is int ? tentativi : 0,
      caricato: FileCaricato.fromMap(dati['caricato']),
    );
  }
}
