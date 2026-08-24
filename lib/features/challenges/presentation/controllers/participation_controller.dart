import 'dart:async';
import 'dart:typed_data';
import 'package:crasy/core/services/media/photo_compressor.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
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
    this.contentType,
    this.isVideo = false,
  });

  final Uint8List bytes;
  final String? contentType;
  final bool isVideo;
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
      'Hai gia\' partecipato a ${Challenge.livesPerDay} gare oggi. '
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
  Future<PickedMedia?> capture(MediaKind kind) async {
    if (kind.isVideo) {
      return _captureVideo();
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
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

  /// Il video, registrato sul momento.
  ///
  /// La durata massima la impone il selettore stesso, non un controllo dopo:
  /// far registrare due minuti per poi dire "troppo lungo, rifallo" e' il modo
  /// piu' sicuro di far perdere una partecipazione.
  Future<PickedMedia?> _captureVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: MediaKind.maxVideoDuration,
    );

    if (picked == null) {
      return null;
    }

    return PickedMedia(
      bytes: await picked.readAsBytes(),
      contentType: picked.mimeType ?? 'video/mp4',
      isVideo: true,
    );
  }

  /// Manda la partecipazione. Torna `true` solo se e' arrivata a destinazione,
  /// cosi' la schermata sa se puo' chiudersi.
  Future<bool> submit({
    required String challengeId,
    required PickedMedia media,
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
    if (ref.read(livesLeftProvider) <= 0) {
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
        contentType: media.contentType,
      ),
    );

    state = result.hasError
        ? AsyncError<void>(result.error!, result.stackTrace!)
        : const AsyncData<void>(null);

    if (!result.hasError) {
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
