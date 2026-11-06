import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/profile/data/repositories/firestore_user_profile_repository.dart';
import 'package:crasy/features/profile/domain/entities/contact_settings.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(
    ref.watch(firebaseFirestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);

/// **Chi e' collegato, e basta: l'identificativo, non la sessione intera.**
///
/// Firebase rimanda l'utente non solo quando si entra e si esce, ma a ogni
/// rinnovo del token e a ogni ricarica dei dati: tre o quattro volte nei primi
/// secondi dopo l'accesso, e poi una volta l'ora. Guardando la sessione intera,
/// il profilo ripartiva da capo a ogni giro, il router passava un istante dal
/// caricamento e la schermata davanti rinasceva vuota. Sui Termini voleva dire
/// spunte sparite e testo aperto con "Leggi" che si chiudeva da solo: il
/// revisore di Apple non riusciva ad accettarli.
///
/// L'identificativo cambia solo quando cambia davvero la persona.
final _signedInUserIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authStateProvider.select(
      (stato) => stato is AuthenticatedAuthState ? stato.user.id : null,
    ),
  );
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final userId = ref.watch(_signedInUserIdProvider);
  final repository = ref.watch(userProfileRepositoryProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  return repository.watchCurrentUserProfile(userId);
});

/// Il numero e la preferenza su chi puo' trovarlo.
///
/// Sta separato dal profilo perche' e' in un documento che solo il
/// proprietario puo' leggere: qui c'e' sempre e solo la propria riga, mai
/// quella di qualcun altro.
final contactSettingsProvider = StreamProvider<ContactSettings>((ref) {
  // Per lo stesso motivo del profilo, qui sopra.
  final userId = ref.watch(_signedInUserIdProvider);
  final repository = ref.watch(userProfileRepositoryProvider);

  if (userId == null) {
    return Stream.value(const ContactSettings());
  }

  return repository.watchContactSettings(userId);
});
