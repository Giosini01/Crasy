import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final profileEditControllerProvider =
    AsyncNotifierProvider<ProfileEditController, void>(
      ProfileEditController.new,
    );

/// Le modifiche a un profilo gia' esistente.
class ProfileEditController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> updateDetails(UserProfile profile, {required String bio}) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(userProfileRepositoryProvider)
          .updateUserProfile(profile.copyWith(bio: bio.trim())),
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
      // La foto profilo finisce in un cerchio da sessanta punti: ventimila
      // pixel di lato sarebbero venti megabyte per niente.
      maxWidth: 720,
      maxHeight: 720,
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
            contentType: picked.mimeType,
          ),
    );

    return true;
  }
}
