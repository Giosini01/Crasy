import 'dart:typed_data';

import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Lo scatto scelto o appena fatto, prima di essere inviato.
///
/// Tiene insieme i byte e il tipo del file. Il tipo va portato dietro e non
/// indovinato: da un iPhone puo' arrivare un HEIC, e dichiararlo JPEG
/// significa consegnare a Storage un file che chi lo rilegge non sa aprire.
class PickedMedia {
  const PickedMedia({required this.bytes, this.contentType});

  final Uint8List bytes;
  final String? contentType;
}

final participationControllerProvider =
    AsyncNotifierProvider<ParticipationController, void>(
      ParticipationController.new,
    );

/// Il giro della partecipazione: scegli una foto, la guardi, la mandi.
class ParticipationController extends AsyncNotifier<void> {
  late final ChallengeRepository _challenges;

  @override
  void build() {
    _challenges = ref.watch(challengeRepositoryProvider);
  }

  /// Apre la fotocamera o la galleria. Torna `null` se l'utente ha rinunciato,
  /// che non e' un errore e non deve produrre un messaggio.
  Future<PickedMedia?> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
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

    return PickedMedia(
      bytes: await picked.readAsBytes(),
      contentType: picked.mimeType,
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

    final profile = ref.read(currentUserProfileProvider).valueOrNull;

    state = const AsyncLoading<void>();
    final result = await AsyncValue.guard(
      () => _challenges.submitEntry(
        challengeId: challengeId,
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

    return !result.hasError;
  }
}
