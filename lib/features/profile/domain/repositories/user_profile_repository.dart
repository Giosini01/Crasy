import 'dart:typed_data';

import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';

abstract class UserProfileRepository {
  /// Carica la foto profilo e la collega al profilo in stato di attesa.
  ///
  /// Come per l'Istantanea il file sale per primo: se l'upload fallisce non
  /// resta un profilo che punta a un'immagine inesistente. A portarla da
  /// "in attesa" a "visibile" e' il server, dopo aver riconosciuto un volto.
  ///
  /// [contentType] e' il tipo vero del file scelto, non uno inventato: chi
  /// legge il file dopo — a partire da chi ci cerca un volto — decide come
  /// aprirlo in base a quello, e dichiarare JPEG un'immagine che JPEG non e'
  /// significa consegnargli un file che non riesce a leggere.
  Future<void> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    String? contentType,
  });

  Future<UserProfile?> getCurrentUserProfile(String userId);

  Stream<UserProfile?> watchCurrentUserProfile(String userId);

  Future<void> createUserProfile(UserProfile profile);

  Future<void> updateUserProfile(UserProfile profile);
}
