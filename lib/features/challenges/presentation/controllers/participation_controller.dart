import 'dart:async';
import 'package:crasy/core/services/media/disk_upload_stub.dart'
    if (dart.library.io) 'package:crasy/core/services/media/disk_upload_io.dart';
import 'package:crasy/core/services/media/photo_compressor.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Lo scatto scelto o appena fatto, prima di essere inviato.
///
/// Tiene insieme i byte e il tipo del file. Il tipo va portato dietro e non
/// indovinato: da un iPhone puo' arrivare un HEIC, e dichiararlo JPEG
/// significa consegnare a Storage un file che chi lo rilegge non sa aprire.
class PickedMedia {
  const PickedMedia({
    required this.bytes,
    this.filePath,
    this.contentType,
    this.isVideo = false,
  });

  final Uint8List bytes;

  /// Dove sta il file **sul telefono**, quando ci sta.
  ///
  /// **Serve ai video, e serve a non far chiudere l'app.** Una foto la
  /// stringiamo noi a poche centinaia di chilobyte, e tenerla in memoria non
  /// costa niente. Un video di trenta secondi no: sono decine di megabyte, e
  /// leggerli tutti per poi consegnarli a chi li spedisce vuol dire chiederne
  /// il doppio al sistema — nel momento peggiore, con la fotocamera ancora
  /// aperta. Quando il sistema dice di no non arriva un errore da mostrare:
  /// l'app si chiude, e la partecipazione e' persa.
  ///
  /// Con il percorso, il file sale **letto a pezzi dal disco** e in memoria non
  /// ci passa mai. Vuoto sul web, dove i file un percorso non ce l'hanno.
  final String? filePath;

  final String? contentType;
  final bool isVideo;

  /// I byte veri, per l'anteprima e per le foto.
  ///
  /// Un video non li ha: non li legge nessuno — l'anteprima del video e' una
  /// conferma scritta, non un fotogramma — e leggerli sarebbe esattamente il
  /// costo che [filePath] esiste per evitare.
  bool get inMemoria => bytes.isNotEmpty;
}

final participationControllerProvider =
    AsyncNotifierProvider<ParticipationController, void>(
      ParticipationController.new,
    );

/// Il giro della partecipazione: scegli una foto, la guardi, la mandi.
/// Le cinque partecipazioni di oggi sono finite.
///
/// Un'eccezione sua invece di un errore qualunque: la schermata la riconosce e
/// dice cosa e' successo, invece di mostrare "qualcosa e' andato storto" per una
/// cosa che non e' andata storta affatto.
class OutOfLivesException implements Exception {
  const OutOfLivesException();

  @override
  String toString() =>
      'Hai già partecipato a ${Challenge.livesPerDay} gare oggi. '
      'A mezzanotte ricominci.';
}

class ParticipationController extends AsyncNotifier<void> {
  late final ChallengeRepository _challenges;

  @override
  void build() {
    _challenges = ref.watch(challengeRepositoryProvider);
  }

  /// Apre la fotocamera. Torna `null` se l'utente ha rinunciato, che non e' un
  /// errore e non deve produrre un messaggio.
  ///
  /// **Non c'e' la galleria**, ed e' la regola piu' importante del prodotto:
  /// una challenge chiede di fare qualcosa *adesso*. Potendo pescare dal
  /// rullino, si vincerebbe con la foto piu' bella che si ha in archivio invece
  /// che con quella piu' folle che si e' avuto il coraggio di fare.
  ///
  /// Su web questo non si puo' imporre: il browser mostra comunque il selettore
  /// di file. E' un limite della piattaforma, non una svista — sul telefono,
  /// dove l'app vive, la fotocamera si apre e basta.
  Future<PickedMedia?> capture(
    MediaKind kind, {
    ChallengeSource from = ChallengeSource.instant,
  }) async {
    if (kind.isVideo) {
      return _captureVideo(from);
    }

    final picked = await ImagePicker().pickImage(
      source: _dove(from),
      // Ridimensionare qui evita di spedire venti megapixel per una foto che
      // verra' guardata su uno schermo da telefono. Su web `image_picker`
      // ignora questi due valori e il file sale com'e': e' un limite noto della
      // piattaforma, non una svista.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );

    if (picked == null) {
      return null;
    }

    final original = await picked.readAsBytes();
    // Si stringe **qui**, prima ancora dell'anteprima: cosi' quello che si vede
    // e' esattamente quello che partira', e non si scopre a cose fatte che il
    // file mandato e' diverso da quello guardato.
    //
    // Su telefono `image_picker` ha gia' fatto il grosso; su web ignora i
    // parametri di ridimensionamento, e senza questo passaggio ogni foto
    // saliva com'era uscita dalla fotocamera — diversi megabyte l'una.
    final shrunk = PhotoCompressor.shrink(original);

    return PickedMedia(
      bytes: shrunk,
      // Il tipo segue quello che si sta davvero mandando: rimpicciolita, la
      // foto e' un JPEG, qualunque cosa fosse prima.
      contentType: shrunk.length == original.length
          ? picked.mimeType
          : 'image/jpeg',
    );
  }

  /// Dove si pesca, e **non c'e' una terza risposta**.
  ///
  /// E' una funzione di due righe e vale piu' di quanto sembri: e' il punto in
  /// cui la regola della gara diventa una cosa che il telefono fa. In una gara
  /// istantanea la galleria non si apre; in una d'archivio la fotocamera non si
  /// apre. Non c'e' nessuna schermata in mezzo che chieda "da dove vuoi
  /// prenderla", perche' quella domanda l'ha gia' fatta chi ha messo i soldi.
  ///
  /// Vedi [ChallengeSource], dove sta scritto perche' mescolarle ucciderebbe la
  /// gara istantanea.
  ImageSource _dove(ChallengeSource from) =>
      from.isArchive ? ImageSource.gallery : ImageSource.camera;

  /// Prepara un file **gia' scattato** dalla fotocamera di CRASY.
  ///
  /// Fa la stessa cosa che si faceva sul risultato del selettore di sistema —
  /// stringere la foto prima ancora dell'anteprima — perche' quello che si vede
  /// deve essere esattamente quello che parte.
  Future<PickedMedia> fromCamera(
    XFile file,
    MediaKind kind, {
    bool mirror = false,
  }) async {
    if (kind.isVideo) {
      // **Un video non si ribalta.** Girarlo vorrebbe dire ricodificarlo tutto
      // sul telefono: decine di secondi di attesa e un file peggiore, per una
      // cosa che nessuno guarda cercandosi la riga dei capelli. Le scritte
      // nello sfondo restano al contrario, ed e' un compromesso — lo stesso che
      // fanno tutti.
      //
      // **E non si legge nemmeno.** Prima si facevano entrare in memoria tutti
      // i suoi megabyte, e non li guardava nessuno: l'anteprima di un video e'
      // una conferma scritta, non un fotogramma. Adesso viaggia il percorso, e
      // il file resta sul disco fino al momento di salire. Vedi
      // `PickedMedia.filePath`.
      return PickedMedia(
        bytes: Uint8List(0),
        // **Subito, non al momento dell'invio.** Il file della fotocamera vive
        // in una cartella del sistema che viene ripulita appena la schermata
        // della fotocamera si chiude: fra qui e "manda in gara" c'e' tutta
        // l'anteprima, e in quel tempo spariva. Vedi `mettiAlSicuro`.
        filePath: await mettiAlSicuro(file.path),
        contentType: file.mimeType ?? 'video/mp4',
        isVideo: true,
      );
    }

    final original = await file.readAsBytes();

    final shrunk = PhotoCompressor.shrink(original, mirror: mirror);

    return PickedMedia(
      bytes: shrunk,
      contentType: shrunk.length == original.length
          ? file.mimeType
          : 'image/jpeg',
    );
  }

  /// Il video, registrato sul momento.
  ///
  /// La durata massima la impone il selettore stesso, non un controllo dopo:
  /// far registrare due minuti per poi dire "troppo lungo, rifallo" e' il modo
  /// piu' sicuro di far perdere una partecipazione.
  Future<PickedMedia?> _captureVideo(ChallengeSource from) async {
    final archivio = from.isArchive;

    final picked = await ImagePicker().pickVideo(
      source: _dove(from),
      // **Il tetto di durata vale solo per chi gira adesso.** Su un video che
      // uno ha gia' non c'e' niente da limitare: il selettore non puo'
      // accorciarlo, quindi il limite si trasformerebbe in un rifiuto secco
      // davanti all'unico video che quella persona voleva mandare.
      maxDuration: archivio ? null : MediaKind.maxVideoDuration,
    );

    if (picked == null) {
      return null;
    }

    // Sul telefono il percorso c'e' e basta quello; sul web non c'e', e li' i
    // byte sono l'unica strada — ma li' arrivano gia' dal browser, e non c'e'
    // una fotocamera aperta a contendersi la memoria.
    return PickedMedia(
      bytes: kIsWeb ? await picked.readAsBytes() : Uint8List(0),
      filePath: kIsWeb ? null : await mettiAlSicuro(picked.path),
      contentType: picked.mimeType ?? 'video/mp4',
      isVideo: true,
    );
  }

  /// Manda la partecipazione. Torna `true` solo se e' arrivata a destinazione,
  /// cosi' la schermata sa se puo' chiudersi.
  Future<bool> submit({
    required String challengeId,
    required PickedMedia media,
    String caption = '',
    bool daily = false,
  }) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      state = AsyncError<void>(
        StateError('Sessione non valida.'),
        StackTrace.current,
      );

      return false;
    }

    // **Cinque gare al giorno, e poi si aspetta domani.** Il controllo sta qui
    // e non solo sul bottone: la schermata puo' restare aperta mentre le altre
    // quattro si consumano altrove, e a quel punto il bottone direbbe una cosa
    // che non e' piu' vera.
    //
    // La sfida del giorno passa sempre: e' gratis, non consuma niente, e deve
    // restare aperta anche a chi ha finito le cinque — anzi, soprattutto a lui,
    // perche' e' l'unica cosa che gli resta da fare fino a domani.
    if (!daily && ref.read(livesLeftProvider) <= 0) {
      state = AsyncError<void>(const OutOfLivesException(), StackTrace.current);

      return false;
    }

    final profile = ref.read(currentUserProfileProvider).valueOrNull;

    state = const AsyncLoading<void>();
    final result = await AsyncValue.guard(
      () => _challenges.submitEntry(
        challengeId: challengeId,
        mediaKind: media.isVideo ? MediaKind.video : MediaKind.photo,
        userId: authState.user.id,
        // Il nome viaggia insieme alla partecipazione. Il feed mostra foto di
        // persone diverse: senza questo campo ogni riga costringerebbe a
        // leggere anche il profilo di chi l'ha scattata.
        authorName: profile?.username ?? 'anonimo',
        bytes: media.bytes,
        filePath: media.filePath,
        contentType: media.contentType,
        // La didascalia viaggia con la foto e nasce con lei: le regole non
        // danno all'autore nessun permesso di aggiornare la propria
        // partecipazione, quindi non si potrebbe aggiungere dopo nemmeno
        // volendo.
        caption: caption,
      ),
    );

    state = result.hasError
        ? AsyncError<void>(result.error!, result.stackTrace!)
        : const AsyncData<void>(null);

    if (!result.hasError) {
      // La copia ha fatto il suo mestiere: se restasse, ogni video registrato
      // occuperebbe il telefono per sempre.
      unawaited(buttaLaCopia(media.filePath ?? ''));

      // Chi ha lanciato la challenge deve sapere che qualcuno l'ha raccolta.
      // E' la notizia piu' importante che l'app abbia da dare: ha messo dei
      // soldi e qualcuno e' uscito di casa per prenderli.
      unawaited(
        _notifyOwner(
          challengeId: challengeId,
          actorId: authState.user.id,
          actorUsername: profile?.username ?? '',
        ),
      );
    }

    return !result.hasError;
  }

  Future<void> _notifyOwner({
    required String challengeId,
    required String actorId,
    required String actorUsername,
  }) async {
    final notifications = ref.read(notificationsRepositoryProvider);
    final challenge = ref.read(challengeProvider(challengeId)).valueOrNull;

    if (notifications == null || challenge == null) {
      return;
    }

    await notifications.push(
      toUserId: challenge.createdByUserId,
      // Una partecipazione a testa, quindi una notifica a testa: il nome del
      // documento lo garantisce senza bisogno di controllare niente.
      id: FirestoreNotificationsRepository.participationId(
        challengeId: challengeId,
        actorId: actorId,
      ),
      kind: NotificationKind.participation,
      actorId: actorId,
      actorUsername: actorUsername,
      challengeId: challengeId,
      challengeTitle: challenge.title,
    );
  }
}
