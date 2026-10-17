import 'dart:async';

import 'package:crasy/core/services/media/archivio_invii.dart';
import 'package:crasy/core/services/media/archivio_invii_stub.dart'
    if (dart.library.io) 'package:crasy/core/services/media/archivio_invii_io.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/invio_in_attesa.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/entities/ritaglio.dart';
import 'package:crasy/features/challenges/presentation/controllers/participation_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Com'e' finito un invio, per dirlo a chi aspetta.
typedef EsitoInvio = ({InvioInAttesa invio, bool inGara, String? messaggio});

/// Dove la coda tiene gli scatti: una cartella sul telefono, la memoria sul
/// web. Un provider a parte perche' le prove lo sostituiscono.
final archivioInviiProvider = Provider<ArchivioInvii>(
  (ref) => creaArchivioInvii(),
);

/// **La coda degli scatti mandati e non ancora arrivati.** Vedi
/// [InvioInAttesa] per il perche'.
final codaInvioProvider = NotifierProvider<CodaInvio, List<InvioInAttesa>>(
  CodaInvio.new,
);

/// Gli esiti degli invii, man mano che arrivano: in gara, o rifiutati.
final esitiInvioProvider = StreamProvider<EsitoInvio>(
  (ref) => ref.watch(codaInvioProvider.notifier).esiti,
);

/// L'invio in attesa per una gara, se ce n'e' uno della persona collegata.
final invioPerGaraProvider = Provider.family<InvioInAttesa?, String>((
  ref,
  challengeId,
) {
  final io = ref.watch(currentUserIdProvider);

  for (final invio in ref.watch(codaInvioProvider)) {
    if (invio.challengeId == challengeId && invio.userId == io) {
      return invio;
    }
  }

  return null;
});

/// Quante partecipazioni del giorno sono in viaggio: contano gia', o con
/// poca rete se ne manderebbero sei.
final partecipazioniInViaggioProvider = Provider<int>((ref) {
  final io = ref.watch(currentUserIdProvider);

  return ref
      .watch(codaInvioProvider)
      .where((invio) => invio.userId == io && !invio.daily)
      .length;
});

class CodaInvio extends Notifier<List<InvioInAttesa>> {
  ArchivioInvii get _archivio => ref.read(archivioInviiProvider);
  final StreamController<EsitoInvio> _esiti = StreamController.broadcast();

  /// Chi aspetta il primo tentativo di un invio appena mandato: `true` se e'
  /// arrivato, `false` se e' andato in pausa per la rete.
  final Map<String, Completer<bool>> _primoTentativo = {};

  /// Quando si puo' riprovare ogni invio in pausa.
  final Map<String, DateTime> _prossimoTentativo = {};

  bool _alLavoro = false;
  Timer? _sveglia;

  Stream<EsitoInvio> get esiti => _esiti.stream;

  @override
  List<InvioInAttesa> build() {
    // **Chi entra ritrova i suoi invii, e partono.** Anche chi esce e
    // rientra con un altro account: ognuno manda solo i propri.
    ref
      ..listen(currentUserIdProvider, (_, _) => riprova())
      ..onDispose(() {
        _sveglia?.cancel();
        unawaited(_esiti.close());
      });

    unawaited(_caricaDalTelefono());

    return const [];
  }

  /// Rilegge gli invii rimasti sul telefono dall'ultima volta, e li manda.
  Future<void> _caricaDalTelefono() async {
    try {
      final schede = await _archivio.leggiLeSchede();
      final ritrovati = <InvioInAttesa>[];

      for (final scheda in schede) {
        final invio = InvioInAttesa.fromJson(scheda);

        if (invio == null) {
          continue;
        }

        // Lo scatto non c'e' piu': la scheda da sola non manda niente.
        if (!_archivio.esiste(invio.file)) {
          await _archivio.butta(invio.id, invio.file);

          continue;
        }

        ritrovati.add(invio);
      }

      if (ritrovati.isEmpty) {
        return;
      }

      ritrovati.sort((a, b) => a.creato.compareTo(b.creato));

      final gia = {for (final invio in state) invio.id};

      state = [
        ...state,
        for (final invio in ritrovati)
          if (!gia.contains(invio.id)) invio,
      ];

      riprova();
    } on Object catch (errore) {
      debugPrint('CRASY: invii in attesa non letti — $errore');
    }
  }

  /// **Mette lo scatto in coda e lo manda.**
  ///
  /// Aspetta al massimo [attesa]. Torna `true` se in quel tempo e' arrivato in
  /// gara; `false` se e' ancora in viaggio o in pausa per la rete — e in quel
  /// caso continua da solo. Se la gara lo rifiuta, lancia l'errore.
  Future<bool> manda({
    required String challengeId,
    required String challengeTitle,
    required String userId,
    required String authorName,
    required PickedMedia media,
    required Duration attesa,
    String caption = '',
    bool muted = false,
    bool daily = false,
    Ritaglio? ritaglio,
  }) async {
    // **Uno per gara.** Con poca rete si potrebbe premere di nuovo, e il
    // secondo scatto partirebbe per una gara che ne accetta uno solo.
    if (state.any(
      (invio) => invio.challengeId == challengeId && invio.userId == userId,
    )) {
      throw const InvioGiaInViaggio();
    }

    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final estensione = media.isVideo
        ? 'mp4'
        : (media.contentType == 'image/png' ? 'png' : 'jpg');

    // **Prima si salva, poi si manda.** Da qui in poi lo scatto non dipende
    // piu' dalla pagina, dalla rete o dall'app aperta.
    final percorso = media.isVideo && (media.filePath ?? '').isNotEmpty
        ? await _archivio.tieniIlFile(id, media.filePath!, estensione)
        : await _archivio.tieniIByte(id, media.bytes, estensione);

    final invio = InvioInAttesa(
      id: id,
      challengeId: challengeId,
      challengeTitle: challengeTitle,
      userId: userId,
      authorName: authorName,
      isVideo: media.isVideo,
      contentType:
          media.contentType ?? (media.isVideo ? 'video/mp4' : 'image/jpeg'),
      file: percorso,
      creato: DateTime.now(),
      caption: caption,
      muted: muted,
      ritaglio: ritaglio,
      daily: daily,
    );

    await _archivio.salvaLaScheda(id, invio.toJson());

    final primo = _primoTentativo[id] = Completer<bool>();

    state = [...state, invio];
    riprova();

    try {
      return await primo.future.timeout(attesa);
    } on TimeoutException {
      // La pagina smette di aspettare: da qui in poi l'esito arriva come
      // avviso, ovunque si sia nell'app.
      _primoTentativo.remove(id);

      return false;
    }
  }

  /// **Riprova adesso tutto quello che e' in pausa.** Si chiama quando l'app
  /// torna davanti, quando cambia chi e' collegato, e quando si tocca
  /// "riprova": sono i momenti in cui la rete e' piu' probabile che ci sia.
  void riprova() {
    _prossimoTentativo.clear();
    unawaited(_lavora());
  }

  /// Uno alla volta: con poca rete due invii insieme si rubano la banda, e
  /// arrivano tutti e due piu' tardi di quanto ci metterebbero in fila.
  Future<void> _lavora() async {
    if (_alLavoro) {
      return;
    }

    _alLavoro = true;
    _sveglia?.cancel();

    try {
      while (true) {
        final io = ref.read(currentUserIdProvider);
        final adesso = DateTime.now();
        InvioInAttesa? prossimo;

        for (final invio in state) {
          final quando = _prossimoTentativo[invio.id];

          if (invio.userId == io &&
              invio.stato == StatoInvio.inPausa &&
              (quando == null || !quando.isAfter(adesso))) {
            prossimo = invio;

            break;
          }
        }

        if (prossimo == null) {
          break;
        }

        await _prova(prossimo);
      }
    } finally {
      _alLavoro = false;
      _programmaLaSveglia();
    }
  }

  /// Fissa il prossimo giro alla prima pausa che scade.
  void _programmaLaSveglia() {
    _sveglia?.cancel();

    final io = ref.read(currentUserIdProvider);
    DateTime? prima;

    for (final invio in state) {
      final quando = _prossimoTentativo[invio.id];

      if (invio.userId != io || quando == null) {
        continue;
      }

      if (prima == null || quando.isBefore(prima)) {
        prima = quando;
      }
    }

    if (prima == null) {
      return;
    }

    final fra = prima.difference(DateTime.now());

    _sveglia = Timer(
      fra.isNegative ? Duration.zero : fra,
      () => unawaited(_lavora()),
    );
  }

  Future<void> _prova(InvioInAttesa invio) async {
    var corrente = invio.copyWith(
      stato: StatoInvio.inViaggio,
      avanzamento: invio.caricato == null ? 0 : 1,
      tentativi: invio.tentativi + 1,
    );

    _metti(corrente);

    try {
      // Lo scatto sparito non torna riprovando: si dice subito.
      if (!_archivio.esiste(corrente.file)) {
        throw StateError("Lo scatto da mandare non c'è più.");
      }

      await _archivio.salvaLaScheda(corrente.id, corrente.toJson());

      // Un video sul telefono sale dal disco, a pezzi; tutto il resto — le
      // foto, e i video sul web — dai byte.
      final dalDisco = corrente.isVideo && !kIsWeb;
      final byte = dalDisco
          ? Uint8List(0)
          : await _archivio.leggi(corrente.file);

      await ref
          .read(challengeRepositoryProvider)
          .submitEntry(
            challengeId: corrente.challengeId,
            userId: corrente.userId,
            authorName: corrente.authorName,
            bytes: byte,
            filePath: dalDisco ? corrente.file : null,
            mediaKind: corrente.isVideo ? MediaKind.video : MediaKind.photo,
            contentType: corrente.contentType,
            caption: corrente.caption,
            muted: corrente.muted,
            ritaglio: corrente.ritaglio,
            giaCaricato: corrente.caricato,
            suAvanzamento: (quanto) => _avanza(corrente.id, quanto),
            suCaricato: (caricato) {
              corrente = corrente.copyWith(caricato: caricato, avanzamento: 1);
              _metti(corrente);
              unawaited(
                _archivio.salvaLaScheda(corrente.id, corrente.toJson()),
              );
            },
          );

      await _arrivato(corrente);
    } on Object catch (errore) {
      if (_definitivo(errore)) {
        await _rifiutato(corrente, errore);

        return;
      }

      // **Con poca rete si aspetta e si riprova**, sempre un po' di piu':
      // cinque secondi, poi dieci, venti, quaranta... fino a cinque minuti.
      // Riprovare ogni secondo consumerebbe la batteria per niente.
      final secondi = (5 * (1 << (corrente.tentativi - 1).clamp(0, 6))).clamp(
        5,
        300,
      );

      _prossimoTentativo[corrente.id] = DateTime.now().add(
        Duration(seconds: secondi),
      );
      _metti(corrente.copyWith(stato: StatoInvio.inPausa));
      _completa(corrente.id, arrivato: false);

      debugPrint(
        'CRASY: invio in pausa (tentativo ${corrente.tentativi}) — $errore',
      );
    }
  }

  Future<void> _arrivato(InvioInAttesa invio) async {
    await _archivio.butta(invio.id, invio.file);
    _togli(invio.id);

    // Chi ha lanciato la gara lo viene a sapere, e una sfida si chiude: e'
    // quello che succedeva prima, appena finito l'invio.
    unawaited(
      ref
          .read(participationControllerProvider.notifier)
          .dopoLInvio(
            challengeId: invio.challengeId,
            userId: invio.userId,
            username: invio.authorName,
          ),
    );

    final attesa = _primoTentativo.remove(invio.id);

    // Se la pagina sta ancora aspettando, "sei in gara" lo dice lei.
    if (attesa != null && !attesa.isCompleted) {
      attesa.complete(true);

      return;
    }

    _esiti.add((invio: invio, inGara: true, messaggio: null));
  }

  Future<void> _rifiutato(InvioInAttesa invio, Object errore) async {
    await _archivio.butta(invio.id, invio.file);
    _togli(invio.id);

    final attesa = _primoTentativo.remove(invio.id);

    // Chi sta ancora guardando la pagina legge l'errore li', come prima.
    if (attesa != null && !attesa.isCompleted) {
      attesa.completeError(errore);

      return;
    }

    _esiti.add((
      invio: invio,
      inGara: false,
      messaggio: _perche(invio, errore),
    ));
  }

  /// **Quando non ha senso riprovare.** La gara e' finita, non c'e' piu', si
  /// e' gia' dentro, lo scatto non c'e' piu', o il database dice di no: la
  /// rete non c'entra, e riprovare darebbe lo stesso risultato per sempre.
  bool _definitivo(Object errore) {
    if (errore is ChallengeClosedException ||
        errore is ChallengeNotFoundException ||
        errore is AlreadyParticipatingException ||
        errore is StateError) {
      return true;
    }

    if (errore is FirebaseException) {
      return errore.code == 'permission-denied' ||
          errore.code == 'unauthorized';
    }

    return false;
  }

  String _perche(InvioInAttesa invio, Object errore) {
    final cosa = invio.isVideo ? 'Il tuo video' : 'La tua foto';
    final per = invio.challengeTitle.isEmpty
        ? ''
        : ' per "${invio.challengeTitle}"';

    if (errore is ChallengeClosedException ||
        (errore is FirebaseException && errore.code == 'permission-denied')) {
      return '$cosa$per non è partito in tempo: la missione si è chiusa prima '
          'che tornasse la rete.';
    }

    if (errore is AlreadyParticipatingException) {
      return 'Eri già in gara$per con un altro scatto.';
    }

    if (errore is ChallengeNotFoundException) {
      return 'La missione$per non c\'è più.';
    }

    return '$cosa$per non è partito: riprova a scattare.';
  }

  /// Risponde alla pagina che aspetta il primo tentativo, se c'e' ancora.
  void _completa(String id, {required bool arrivato}) {
    final attesa = _primoTentativo.remove(id);

    if (attesa != null && !attesa.isCompleted) {
      attesa.complete(arrivato);
    }
  }

  void _avanza(String id, double quanto) {
    state = [
      for (final invio in state)
        invio.id == id ? invio.copyWith(avanzamento: quanto) : invio,
    ];
  }

  void _metti(InvioInAttesa aggiornato) {
    state = [
      for (final invio in state) invio.id == aggiornato.id ? aggiornato : invio,
    ];
  }

  void _togli(String id) {
    _prossimoTentativo.remove(id);
    state = [
      for (final invio in state)
        if (invio.id != id) invio,
    ];
  }
}

/// Per questa gara sta gia' partendo uno scatto: uno basta.
class InvioGiaInViaggio implements Exception {
  const InvioGiaInViaggio();

  @override
  String toString() =>
      'Sta già partendo il tuo scatto per questa missione: aspetta che arrivi.';
}
