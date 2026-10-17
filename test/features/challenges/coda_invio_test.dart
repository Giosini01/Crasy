import 'dart:typed_data';

import 'package:crasy/core/services/media/archivio_invii.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/file_caricato.dart';
import 'package:crasy/features/challenges/domain/entities/invio_in_attesa.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/entities/ritaglio.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:crasy/features/challenges/presentation/controllers/coda_invio_controller.dart';
import 'package:crasy/features/challenges/presentation/controllers/participation_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// **La coda d'invio: uno scatto mandato con poca rete non si perde.**
void main() {
  late _RepositorioFinto repositorio;
  late _ArchivioInMemoria archivio;
  late ProviderContainer container;

  setUp(() {
    repositorio = _RepositorioFinto();
    archivio = _ArchivioInMemoria();
    container = ProviderContainer(
      overrides: [
        challengeRepositoryProvider.overrideWithValue(repositorio),
        archivioInviiProvider.overrideWithValue(archivio),
        currentUserIdProvider.overrideWithValue('io'),
        participationControllerProvider.overrideWith(_DopoFinto.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(codaInvioProvider);
  });

  Future<bool> manda({Duration attesa = const Duration(seconds: 5)}) {
    return container
        .read(codaInvioProvider.notifier)
        .manda(
          challengeId: 'gara',
          challengeTitle: 'Il cane',
          userId: 'io',
          authorName: 'gio',
          media: PickedMedia(bytes: Uint8List.fromList([1, 2, 3])),
          caption: 'ciao',
          attesa: attesa,
        );
  }

  test('con la rete arriva subito, e del telefono non resta niente', () async {
    expect(await manda(), isTrue);

    expect(repositorio.tentativi, 1);
    expect(container.read(codaInvioProvider), isEmpty);
    expect(archivio.schede, isEmpty);
    expect(archivio.byte, isEmpty);
    expect(repositorio.ultimaDidascalia, 'ciao');
  });

  test('senza rete resta salvato, e riprovando arriva', () async {
    repositorio.errori.add(FirebaseException(plugin: 'x', code: 'unavailable'));

    // Il primo tentativo cade: la pagina lo sa subito, e lo scatto resta.
    expect(await manda(), isFalse);

    final inAttesa = container.read(codaInvioProvider).single;

    expect(inAttesa.stato, StatoInvio.inPausa);
    expect(archivio.schede, contains(inAttesa.id));
    expect(archivio.byte, isNotEmpty);

    // Torna la rete: chi aspetta lo viene a sapere dagli avvisi.
    final esito = container.read(codaInvioProvider.notifier).esiti.first;

    container.read(codaInvioProvider.notifier).riprova();

    final arrivato = await esito.timeout(const Duration(seconds: 5));

    expect(arrivato.inGara, isTrue);
    expect(repositorio.tentativi, 2);
    expect(container.read(codaInvioProvider), isEmpty);
    expect(archivio.byte, isEmpty);
  });

  test('il file gia salito non si rimanda', () async {
    // Sale il file, poi cade la scrittura in gara.
    repositorio.cadeDopoIlFile = true;

    expect(await manda(), isFalse);
    expect(container.read(codaInvioProvider).single.caricato, isNotNull);

    final esito = container.read(codaInvioProvider.notifier).esiti.first;

    container.read(codaInvioProvider.notifier).riprova();
    await esito.timeout(const Duration(seconds: 5));

    // Il secondo tentativo riparte dal file gia' salito.
    expect(repositorio.giaCaricatiRicevuti.last?.storagePath, 'su/storage');
    expect(repositorio.fileSaliti, 1);
  });

  test('se la gara si e chiusa non si riprova', () async {
    repositorio.errori.add(const ChallengeClosedException());

    await expectLater(manda(), throwsA(isA<ChallengeClosedException>()));

    expect(container.read(codaInvioProvider), isEmpty);
    expect(archivio.schede, isEmpty);
  });

  test('uno scatto per gara: il secondo non parte', () async {
    repositorio.errori.add(FirebaseException(plugin: 'x', code: 'unavailable'));

    expect(await manda(), isFalse);
    await expectLater(manda(), throwsA(isA<InvioGiaInViaggio>()));
  });

  test('le schede rimaste sul telefono ripartono con l app', () async {
    final rimasta = InvioInAttesa(
      id: 'vecchio',
      challengeId: 'gara',
      challengeTitle: 'Il cane',
      userId: 'io',
      authorName: 'gio',
      isVideo: false,
      contentType: 'image/jpeg',
      file: 'memoria:vecchio',
      creato: DateTime(2026, 10, 17),
      ritaglio: const Ritaglio(x: 0, y: 0.1, larghezza: 1, altezza: 0.8),
    );

    final altra = _ArchivioInMemoria()
      ..schede['vecchio'] = rimasta.toJson()
      ..byte['vecchio'] = Uint8List.fromList([9]);
    final altroRepositorio = _RepositorioFinto();
    final riaperta = ProviderContainer(
      overrides: [
        challengeRepositoryProvider.overrideWithValue(altroRepositorio),
        archivioInviiProvider.overrideWithValue(altra),
        currentUserIdProvider.overrideWithValue('io'),
        participationControllerProvider.overrideWith(_DopoFinto.new),
      ],
    );
    addTearDown(riaperta.dispose);

    final esito = riaperta.read(codaInvioProvider.notifier).esiti.first;
    final arrivato = await esito.timeout(const Duration(seconds: 5));

    expect(arrivato.inGara, isTrue);
    expect(altroRepositorio.ultimoRitaglio, rimasta.ritaglio);
    expect(altra.schede, isEmpty);
  });

  test('la scheda si rilegge uguale', () {
    final invio = InvioInAttesa(
      id: '1',
      challengeId: 'gara',
      challengeTitle: 'Titolo',
      userId: 'io',
      authorName: 'gio',
      isVideo: true,
      contentType: 'video/mp4',
      file: '/percorso/1.mp4',
      creato: DateTime(2026, 10, 17, 20),
      caption: 'frase',
      muted: true,
      daily: true,
      tentativi: 3,
      caricato: const FileCaricato(storagePath: 'a', mediaUrl: 'b'),
    );

    final riletto = InvioInAttesa.fromJson(invio.toJson())!;

    expect(riletto.toJson(), invio.toJson());
    expect(InvioInAttesa.fromJson({'id': ''}), isNull);
  });
}

class _DopoFinto extends ParticipationController {
  @override
  Future<void> dopoLInvio({
    required String challengeId,
    required String userId,
    required String username,
  }) async {}
}

/// L'archivio delle prove: tutto in memoria, niente cartelle.
class _ArchivioInMemoria implements ArchivioInvii {
  final Map<String, Map<String, Object?>> schede = {};
  final Map<String, Uint8List> byte = {};

  @override
  Future<String> tieniIByte(
    String id,
    Uint8List dati,
    String estensione,
  ) async {
    byte[id] = dati;

    return 'memoria:$id';
  }

  @override
  Future<String> tieniIlFile(String id, String percorso, String estensione) =>
      throw UnsupportedError('niente file nelle prove');

  @override
  Future<Uint8List> leggi(String percorso) async =>
      byte[percorso.replaceFirst('memoria:', '')] ?? Uint8List(0);

  @override
  bool esiste(String percorso) =>
      byte.containsKey(percorso.replaceFirst('memoria:', ''));

  @override
  Future<void> salvaLaScheda(String id, Map<String, Object?> scheda) async {
    schede[id] = scheda;
  }

  @override
  Future<List<Object?>> leggiLeSchede() async => schede.values.toList();

  @override
  Future<void> butta(String id, String file) async {
    schede.remove(id);
    byte.remove(id);
  }
}

/// Un repository che fallisce quando glielo si chiede.
class _RepositorioFinto implements ChallengeRepository {
  /// Gli errori dei prossimi tentativi, uno per tentativo.
  final List<Object> errori = [];

  /// Il prossimo tentativo fa salire il file e poi cade.
  bool cadeDopoIlFile = false;

  int tentativi = 0;
  int fileSaliti = 0;
  String? ultimaDidascalia;
  Ritaglio? ultimoRitaglio;
  final List<FileCaricato?> giaCaricatiRicevuti = [];

  @override
  Future<ChallengeEntry> submitEntry({
    required String challengeId,
    required String userId,
    required String authorName,
    required Uint8List bytes,
    String? filePath,
    MediaKind mediaKind = MediaKind.photo,
    String? contentType,
    String caption = '',
    bool muted = false,
    Ritaglio? ritaglio,
    void Function(double avanzamento)? suAvanzamento,
    FileCaricato? giaCaricato,
    void Function(FileCaricato caricato)? suCaricato,
  }) async {
    tentativi++;
    giaCaricatiRicevuti.add(giaCaricato);

    if (errori.isNotEmpty) {
      throw errori.removeAt(0);
    }

    if (giaCaricato == null) {
      fileSaliti++;
      suAvanzamento?.call(1);
      suCaricato?.call(
        const FileCaricato(storagePath: 'su/storage', mediaUrl: 'https://x'),
      );
    }

    if (cadeDopoIlFile) {
      cadeDopoIlFile = false;

      throw FirebaseException(plugin: 'x', code: 'unavailable');
    }

    ultimaDidascalia = caption;
    ultimoRitaglio = ritaglio;

    return ChallengeEntry(
      id: userId,
      challengeId: challengeId,
      challengeTitle: '',
      userId: userId,
      authorName: authorName,
      mediaUrl: 'https://x',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
