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
  /// Quali fra [candidates] sono gia' di qualcuno.
  ///
  /// **Tutti insieme, in una lettura sola.** Chiedere uno per uno costerebbe
  /// una lettura per candidato a ogni tasto premuto mentre si scrive il proprio
  /// nome, ed e' esattamente il tipo di conto che non si vede finche' non
  /// arriva la bolletta.
  Future<Set<String>> takenUsernames(List<String> candidates);

  /// Segna che il giro di presentazione e' stato fatto.
  ///
  /// Un metodo suo invece di passare dal salvataggio del profilo: quello
  /// riscrive nome, biografia e citta' tutti insieme, e usarlo qui vorrebbe
  /// dire poter sovrascrivere il profilo con una copia vecchia solo per aver
  /// finito il tutorial.
  Future<void> markTutorialSeen(String userId);

  Future<void> saveConsent({
    required String userId,
    required String version,
    required bool marketing,
    required bool profiling,
  });

  /// Cancella tutto quello che di [userId] si puo' cancellare da qui.
  ///
  /// **Non e' tutto, ed e' importante dirlo invece di far finta.** Le foto
  /// mandate a gare ancora aperte restano fino alla fine della gara: sono in
  /// mezzo a una competizione con dei soldi in palio, e toglierle mentre gli
  /// altri stanno ancora giocando e' un patto rotto. Le cancella lo spazzino
  /// poco dopo la chiusura, insieme a quelle di tutti gli altri.
  ///
  /// Resta anche la foto che ha **vinto** una gara: e' il trofeo di chi l'ha
  /// commissionata, e non e' piu' solo un dato di chi se n'e' andato.
  ///
  /// Quello che sparisce subito: profilo, foto profilo, fiamme date, notifiche,
  /// amicizie e richieste, e le partecipazioni alle gare gia' chiuse.
  Future<void> eraseUserData(String userId);
}
