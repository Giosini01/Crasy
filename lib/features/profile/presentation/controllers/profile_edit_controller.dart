import 'package:app_incontri/core/services/location_service.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final profileEditControllerProvider =
    AsyncNotifierProvider<ProfileEditController, void>(
      ProfileEditController.new,
    );

/// Modifiche a un profilo gia' esistente.
///
/// Serve a chi si e' registrato prima che un campo esistesse: l'onboarding non
/// si ripresenta piu' una volta completato, quindi senza queste azioni un
/// vecchio profilo resterebbe per sempre senza posizione, senza bio o senza
/// foto.
class ProfileEditController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> refreshLocation(UserProfile profile) async {
    state = const AsyncLoading<void>();

    state = await AsyncValue.guard(() async {
      final coordinates = await ref
          .read(locationServiceProvider)
          .currentApproximateLocation();

      await _save(profile.copyWith(coordinates: coordinates));
    });
  }

  Future<void> updateInterests(
    UserProfile profile,
    List<String> interests,
  ) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => _save(profile.copyWith(interests: interests)),
    );
  }

  Future<void> updateIcebreaker(UserProfile profile, String icebreaker) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => _save(profile.copyWith(icebreaker: icebreaker.trim())),
    );
  }

  /// Sceglie una foto e la carica. Torna `false` se l'utente ha rinunciato,
  /// cosi' chi chiama non mostra un errore per una scelta legittima.
  Future<bool> pickAndUploadPhoto(
    UserProfile profile,
    ImageSource source,
  ) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      // Ridimensionare qui evita di spedire venti megapixel per una foto che
      // verra' mostrata in un cerchio da settanta punti.
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked == null) {
      return false;
    }

    final bytes = await picked.readAsBytes();

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(userProfileRepositoryProvider)
          .uploadPhoto(
            userId: profile.id,
            bytes: bytes,
            // Sul web `image_picker` restituisce il file **come sta**:
            // ridimensionamento e qualita' qui sopra non vengono applicati, e
            // da un iPhone puo' arrivare qualcosa che non e' un JPEG. Il tipo
            // vero va dichiarato, non indovinato.
            contentType: picked.mimeType,
          ),
    );

    return true;
  }

  Future<void> _save(UserProfile profile) {
    return ref.read(userProfileRepositoryProvider).updateUserProfile(profile);
  }
}
