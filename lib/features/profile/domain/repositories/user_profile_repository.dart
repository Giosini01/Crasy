import 'dart:typed_data';

import 'package:crasy/features/profile/domain/entities/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> getCurrentUserProfile(String userId);

  Stream<UserProfile?> watchCurrentUserProfile(String userId);

  Future<void> createUserProfile(UserProfile profile);

  Future<void> updateUserProfile(UserProfile profile);

  /// Carica la foto profilo e la collega al profilo.
  ///
  /// Il file sale per primo: se l'upload fallisce non resta un profilo che
  /// punta a un'immagine inesistente.
  ///
  /// [contentType] e' il tipo vero del file scelto, non uno inventato: chi
  /// legge il file dopo decide come aprirlo in base a quello, e dichiarare
  /// JPEG un'immagine che JPEG non e' significa consegnargli un file che non
  /// riesce ad aprire.
  Future<void> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    String? contentType,
  });

  /// Registra cosa questa persona ha accettato, e quando.
  ///
  /// Scrive in due posti e servono tutti e due: sul profilo, perche' l'app
  /// deve sapere in un colpo d'occhio se la versione accettata e' quella di
  /// oggi; e in un **registro che non si puo' modificare**, perche' il GDPR non
  /// chiede solo di raccogliere il consenso ma di **dimostrarlo** — chi, a che
  /// cosa, quando. Un campo che si sovrascrive a ogni cambio non dimostra
  /// niente: cancella la storia mentre la aggiorna.
  Future<void> saveConsent({
    required String userId,
    required String version,
    required bool marketing,
    required bool profiling,
  });
}
