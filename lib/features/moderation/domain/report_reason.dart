import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';

/// Perche' si sta segnalando qualcosa.
///
/// **Sono poche e sono secche.** Un elenco di quindici voci sembra piu' serio e
/// funziona peggio: chi segnala ha appena visto una cosa che l'ha disturbato,
/// non ha voglia di scegliere fra sfumature, e davanti a un menu lungo chiude e
/// se ne va. Otto voci si leggono tutte in un colpo d'occhio.
///
/// L'ultima e' quella che tiene in piedi le altre: qualunque cosa non stia
/// nelle voci sopra ha comunque un posto dove finire.
///
/// **I nomi sono scritti sul database**, e sono anche in `firestore.rules`, in
/// `functions/avvisi.js` e nel pannello: `hate` adesso si legge "molestie o
/// bullismo" ma resta `hate`, o le segnalazioni gia' in archivio cambierebbero
/// motivo senza che nessuno le abbia toccate.
enum ReportReason {
  /// Il caso piu' grave, e sta per primo apposta.
  danger(
    'Mette in pericolo qualcuno',
    'Chiede o mostra qualcosa che può far male a una persona.',
  ),

  sexual('Contenuto sessualmente esplicito', 'Nudità o contenuti sessuali.'),

  violence('Violenza', 'Aggressioni, crudelta\' su persone o animali.'),

  hate(
    'Molestie o bullismo',
    'Insulti, minacce, odio o discriminazioni contro una persona o un gruppo.',
  ),

  illegal('Contenuto illegale', 'Mostra o chiede di commettere un reato.'),

  spam('Spam o frode', 'Pubblicità, truffe, account falsi.'),

  minor('C\'è un minore', 'Nella foto o nel video compare un minorenne.'),

  other('Altro', 'Qualcosa che non dovrebbe stare qui.');

  const ReportReason(this.label, this.detail);

  /// Come si chiama nella lista.
  final String label;

  /// La riga sotto: serve a far scegliere la voce giusta senza doverci pensare.
  final String detail;

  static ReportReason fromName(String? value) {
    for (final reason in ReportReason.values) {
      if (reason.name == value) {
        return reason;
      }
    }

    return ReportReason.other;
  }
}

/// Cosa si sta segnalando.
enum ReportTargetKind {
  /// Una foto o un video in gara.
  entry,

  /// Un commento sotto una foto.
  comment,

  /// Una persona.
  user,

  /// Una missione: il testo della consegna, non le foto.
  challenge,
}

/// **Quello su cui si apre il menu**: un contenuto e chi l'ha pubblicato.
///
/// Sta in un oggetto solo perche' viaggia intero dal menu alla segnalazione o al
/// blocco: nove parametri ripetuti in quattro funzioni sono nove occasioni di
/// passarne uno sbagliato.
class ReportTarget {
  const ReportTarget({
    required this.kind,
    required this.reportedUserId,
    required this.reportedUsername,
    this.challengeId = '',
    this.entryId = '',
    this.commentId = '',
    this.mediaUrl = '',
    this.challengeTitle = '',
    this.commentText = '',
  });

  /// Una foto o un video in gara. **La partecipazione si chiama come chi l'ha
  /// mandata**, e le regole pretendono che i due coincidano: non si puo' segnalare
  /// una foto a nome di qualcun altro.
  factory ReportTarget.diFoto(ChallengeEntry entry) => ReportTarget(
    kind: ReportTargetKind.entry,
    reportedUserId: entry.userId,
    reportedUsername: entry.authorName,
    challengeId: entry.challengeId,
    entryId: entry.id,
    mediaUrl: entry.mediaUrl,
    challengeTitle: entry.challengeTitle,
  );

  final ReportTargetKind kind;

  /// Chi l'ha pubblicato. Vuoto in una missione anonima: si segnala, ma non si
  /// sa chi e' e quindi non si blocca.
  final String reportedUserId;
  final String reportedUsername;

  final String challengeId;
  final String entryId;
  final String commentId;

  /// La foto e il titolo della gara, quando ci sono.
  ///
  /// Viaggiano dentro la segnalazione perche' la dashboard deve poter mostrare
  /// **cosa** e' stato segnalato anche dopo che la partecipazione e' stata
  /// cancellata dalla pulizia delle quarantotto ore.
  final String mediaUrl;
  final String challengeTitle;

  /// Il testo del commento segnalato: il commento si puo' cancellare, e la
  /// segnalazione deve poter dire cosa c'era scritto.
  final String commentText;

  /// Se c'e' qualcuno da bloccare.
  bool get bloccabile => reportedUserId.isNotEmpty;

  /// Come si chiama, in una frase.
  String get cosa => switch (kind) {
    ReportTargetKind.entry => 'questa foto',
    ReportTargetKind.comment => 'questo commento',
    ReportTargetKind.challenge => 'questa missione',
    ReportTargetKind.user => 'questa persona',
  };
}

/// Com'e' andata una segnalazione.
enum ReportOutcome {
  sent,

  /// **L'avevi gia' segnalata.** Non e' un errore e non va raccontata come tale:
  /// la segnalazione c'e', e qualcuno la guardera'.
  alreadySent,

  failed,
}
