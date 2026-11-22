import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/gioco/data/gioco_repository.dart';
import 'package:crasy/features/gioco/domain/entities/regole_del_gioco.dart';
import 'package:crasy/features/gioco/domain/entities/stato_del_gioco.dart';
import 'package:crasy/features/gioco/domain/sfide_in_vista.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final giocoRepositoryProvider = Provider<GiocoRepository?>((ref) {
  if (!ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return null;
  }

  return GiocoRepository(
    ref.watch(firebaseFirestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

/// Le regole del gioco: sfide, traguardi, livelli. Nulle finche' il server
/// non le ha scritte — succede al primo fatto contato, o aprendo le sfide.
final regoleDelGiocoProvider = StreamProvider<RegoleDelGioco?>((ref) {
  final repository = ref.watch(giocoRepositoryProvider);

  if (repository == null) {
    return Stream.value(null);
  }

  return repository.watchRegole();
});

/// Lo stato di chi guarda. Su piu' telefoni e' lo stesso documento: quello
/// che si fa su uno si vede sull'altro mentre succede.
final statoDelGiocoProvider = StreamProvider<StatoDelGioco?>((ref) {
  final repository = ref.watch(giocoRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return Stream.value(null);
  }

  return repository.watchStato(userId);
});

/// I premi che arrivano adesso, per la festa: vedi `CrasyApp`.
final premiNuoviProvider = StreamProvider<PremioXp>((ref) {
  final repository = ref.watch(giocoRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return const Stream.empty();
  }

  return repository.premiNuovi(userId);
});

/// **Le sfide di oggi chieste al server, una volta per sessione.** La
/// schermata delle sfide lo richiede da se' ogni volta che si apre: e' il
/// posto in cui il giorno nuovo deve arrivare di sicuro.
final apriLeSfideProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(giocoRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (repository == null || userId == null) {
    return;
  }

  try {
    await repository.apri();
  } on Object {
    // Senza rete restano quelle di prima: al prossimo giro si riprova.
  }
});

/// Il livello, con il nome e quanto manca: dalle regole e dagli XP.
final livelloAttualeProvider = Provider<LivelloAttuale?>((ref) {
  final regole = ref.watch(regoleDelGiocoProvider).valueOrNull;
  final stato = ref.watch(statoDelGiocoProvider).valueOrNull;

  if (regole == null || stato == null) {
    return null;
  }

  return regole.livelloPer(stato.xp);
});

final sfideDiOggiProvider = Provider<List<SfidaInVista>>((ref) {
  final regole = ref.watch(regoleDelGiocoProvider).valueOrNull;
  final stato = ref.watch(statoDelGiocoProvider).valueOrNull;

  if (regole == null || stato == null) {
    return const [];
  }

  return sfideDiOggi(regole, stato);
});

final traguardiProvider = Provider<List<SfidaInVista>>((ref) {
  final regole = ref.watch(regoleDelGiocoProvider).valueOrNull;
  final stato = ref.watch(statoDelGiocoProvider).valueOrNull;

  if (regole == null || stato == null) {
    return const [];
  }

  return traguardi(regole, stato);
});
