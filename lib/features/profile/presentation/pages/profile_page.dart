import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/count_dot.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/media_gestures.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/auth/presentation/controllers/auth_action_controller.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:crasy/features/payments/presentation/widgets/wallet_card.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/controllers/profile_edit_controller.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/features/profile/presentation/widgets/profile_settings.dart';
import 'package:crasy/features/profile/presentation/widgets/profile_shelf.dart';
import 'package:crasy/features/profile/presentation/widgets/trophy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Il profilo: quello che hai fatto, non quello che sei.
///
/// Tre numeri e una griglia di foto. Non c'e' una copertina, non ci sono badge,
/// non c'e' un livello da salire: su CRASY una persona vale le foto che ha
/// mandato e le challenge che ha vinto, ed e' tutto li' sopra.
///
/// L'impaginazione segue la stessa regola delle challenge — un blocco grande in
/// cima, una riga di numeri, poi il contenuto — cosi' il profilo non sembra una
/// schermata presa da un'altra app.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  ProfileShelf _shelf = ProfileShelf.live;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profileState = ref.watch(currentUserProfileProvider);
    final entries = ref.watch(myEntriesProvider).valueOrNull ?? const [];
    final wins = ref.watch(myWinsProvider);
    final liveChallenges =
        ref.watch(liveChallengesProvider).valueOrNull ?? const <Challenge>[];
    final live = liveChallenges.map((challenge) => challenge.id).toSet();
    final shown = liveEntries(entries, live);
    final trophies = ref.watch(myTrophiesProvider).valueOrNull ?? const [];
    final commissions =
        ref.watch(myCommissionsProvider).valueOrNull ?? const [];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // L'ingranaggio sta **qui e non in fondo alla schermata**: privacy
              // e cancellazione dell'account sono le due porte che si aprono
              // una volta nella vita, e in fondo alla pagina si allontanavano a
              // ogni gara vinta, sotto una griglia di foto che cresce.
              CrasyHeaderBar(
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // **La modifica sale qui, accanto all'ingranaggio.**
                    //
                    // Stava dentro il profilo, accanto alla foto: un'icona in
                    // mezzo al contenuto, che scorreva via appena si guardavano
                    // le proprie foto. I due comandi che riguardano *te* — cosa
                    // scrivi di te e cosa hai accettato — sono la stessa
                    // famiglia e stanno bene insieme, in cima e sempre ferme.
                    //
                    // Si vedono solo qui perche' la barra con l'azione ce l'ha
                    // solo questa scheda: sulle altre il marchio sta da solo.
                    if (profileState.valueOrNull case final mio?)
                      IconButton(
                        onPressed: () => editProfile(context, ref, mio),
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        tooltip: 'Modifica profilo',
                        color: palette.textFaint,
                      ),
                    IconButton(
                      onPressed: () => showProfileSettings(context),
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      tooltip: 'Impostazioni',
                      color: palette.textFaint,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: profileState.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                    child: EmptyState(
                      title: 'Profilo non disponibile',
                      message:
                          'Non riusciamo a leggere il tuo profilo. Riprova.',
                    ),
                  ),
                  data: (profile) {
                    if (profile == null) {
                      return const SizedBox.shrink();
                    }

                    return ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          child: _Identity(profile: profile),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Il portafoglio sta **prima** dei numeri: gli altri tre
                        // raccontano cosa hai fatto, questo dice cosa ti spetta.
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          child: WalletCard(),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _Stats(
                          entries: entries.length,
                          wins: wins.length,
                          friends:
                              ref
                                  .watch(myFriendsProvider)
                                  .valueOrNull
                                  ?.length ??
                              0,
                          pending:
                              ref
                                  .watch(incomingRequestsProvider)
                                  .valueOrNull
                                  ?.length ??
                              0,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ProfileShelfTabs(
                          selected: _shelf,
                          onPick: (shelf) => setState(() => _shelf = shelf),
                        ),
                        switch (_shelf) {
                          ProfileShelf.live =>
                            shown.isEmpty
                                ? const _EmptyShelf(
                                    title: 'Non sei in nessuna gara',
                                    message:
                                        'Le foto che mandi alle challenge aperte stanno qui '
                                        'finche\' la gara non finisce.',
                                  )
                                : _EntryGrid(entries: shown),
                          ProfileShelf.trophies =>
                            trophies.isEmpty
                                ? const _EmptyShelf(
                                    title: 'Nessun trofeo, per ora',
                                    message:
                                        'Qui finiscono le missioni che vinci: '
                                        'la foto resta, con quanto ti ha fatto '
                                        'incassare. Partecipa a una challenge '
                                        'e prenditi la prima.',
                                  )
                                : TrophyGrid(
                                    challenges: trophies,
                                    kind: TrophyKind.won,
                                  ),
                          ProfileShelf.commissioned =>
                            commissions.isEmpty
                                ? const _EmptyShelf(
                                    title: 'Non hai ancora fatto fare niente',
                                    message:
                                        'Lancia una challenge: la vedi qui finche\' e\' '
                                        'aperta, e quando finisce resta la foto che ha '
                                        'vinto — roba che hai fatto fare tu.',
                                  )
                                : CommissionedShelf(challenges: commissions),
                        },
                        const SizedBox(height: AppSpacing.xl),
                        // **Uscire resta in chiaro.** Non e' un'impostazione:
                        // e' un gesto che si fa spesso e in fretta, e mettergli
                        // davanti un menu vorrebbe dire due tocchi per una cosa
                        // che ne chiede uno.
                        //
                        // Privacy e cancellazione dell'account stavano qui
                        // sotto e ora stanno nell'ingranaggio in alto a destra.
                        // Non sono state nascoste, e la differenza conta perche'
                        // il GDPR chiede che revocare un consenso sia facile
                        // quanto darlo: qui in fondo cadevano dopo una griglia
                        // di foto che si allunga a ogni gara, cioe' **piu'
                        // lontane ogni mese**. In cima stanno sempre allo
                        // stesso posto.
                        Center(
                          child: TextButton(
                            onPressed: () => ref
                                .read(authActionControllerProvider.notifier)
                                .signOut(),
                            child: Text(
                              'Esci',
                              style: context.texts.titleMedium?.copyWith(
                                color: palette.textFaint,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chi sei: la foto, il nome grande, una riga, la citta'.
class _Identity extends ConsumerWidget {
  const _Identity({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_Avatar(profile: profile, onTap: () => _changePhoto(ref))],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('@${profile.username}', style: texts.displaySmall),
        if (profile.hasBio) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(profile.bio, style: texts.bodyMedium),
        ],
      ],
    );
  }

  /// Cambia la faccia del profilo, prendendola dalla galleria.
  ///
  /// **Non si scatta piu' sul momento, e non c'e' piu' niente da scegliere.**
  /// Prima si apriva un foglio con due voci; adesso si apre direttamente la
  /// galleria.
  ///
  /// Due ragioni. La foto del profilo non e' una gara: e' la faccia con cui uno
  /// si presenta, e la si sceglie fra quelle che ha gia' — quella buona,
  /// quella di quella sera — non facendosi un selfie in quel preciso istante,
  /// che e' il momento peggiore possibile per farselo. Chi la vuole nuova la
  /// scatta col telefono e poi la prende da li': un passaggio in piu' per il
  /// caso raro, zero passaggi per quello normale.
  ///
  /// E un foglio che si apre per far scegliere fra due cose, quando una delle
  /// due non la sceglie quasi nessuno, e' solo un tocco in mezzo alla strada.
  Future<void> _changePhoto(WidgetRef ref) async {
    await ref
        .read(profileEditControllerProvider.notifier)
        .pickAndUploadPhoto(profile, ImageSource.gallery);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: profile.hasPhoto
                    ? Image.network(
                        profile.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _Initials(profile: profile),
                      )
                    : _Initials(profile: profile),
              ),
            ),
            // Il segno che la foto si puo' cambiare. Piccolo e sul bordo:
            // deve farsi trovare da chi lo cerca, non annunciarsi.
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: palette.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.line),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 12,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      color: palette.surfaceMuted,
      child: Center(
        child: Text(
          profile.initials,
          style: context.texts.headlineSmall?.copyWith(
            color: palette.textFaint,
          ),
        ),
      ),
    );
  }
}

/// I tre numeri, fra due filetti.
///
/// Sono tre: scatti, vinte, amici. Tutto il resto — visualizzazioni, fiamme
/// ricevute, giorni di fila — sarebbe roba da far salire per il gusto di farla
/// salire.
///
/// **I soldi non stanno qui**, e prima ci stavano due volte: una nel
/// portafoglio, in cima e in grande, e una in questa riga come "VINTI". Lo
/// stesso numero scritto due volte nella stessa schermata non e' un rinforzo,
/// e' il dubbio che siano due numeri diversi.
class _Stats extends StatelessWidget {
  const _Stats({
    required this.entries,
    required this.wins,
    required this.friends,
    this.pending = 0,
  });

  final int entries;
  final int wins;
  final int friends;

  /// Le richieste di amicizia che aspettano una risposta.
  final int pending;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Divider(color: palette.line),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat(label: 'SCATTI', value: '$entries'),
              _Divider(color: palette.line),
              _Stat(label: 'VINTE', value: '$wins'),
              _Divider(color: palette.line),
              // **Da qui si entra.** Il conto degli amici era gia' li' e
              // adesso e' anche la porta: si tocca il numero e si apre
              // l'elenco. E' il posto in cui uno li cerca — quello in cui sono
              // contati — e non ne serviva un altro.
              _Stat(
                label: 'AMICI',
                value: '$friends',
                onTap: () => context.push(AppRoutes.friends),
                waiting: pending,
              ),
            ],
          ),
        ),
        Divider(color: palette.line),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 34, color: color);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.onTap,
    this.waiting = 0,
  });

  final String label;
  final String value;

  /// Se questo numero porta da qualche parte.
  final VoidCallback? onTap;

  /// Quante cose stanno aspettando una risposta la' dentro.
  ///
  /// **E' il pallino che stava sulla scheda in fondo.** Una richiesta di
  /// amicizia e' l'unica cosa dell'app che aspetta qualcosa da te: togliendo la
  /// scheda senza portarsi dietro il numero, quelle richieste sarebbero
  /// diventate invisibili — e chi le manda aspetterebbe per sempre.
  final int waiting;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: texts.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (waiting > 0) ...[
                  const SizedBox(width: 5),
                  // **Lo stesso pallino della campanella, non uno somigliante.**
                  // Prima era una pastiglia schiacciata larga quanto le cifre
                  // che aveva dentro: due segni rossi che vogliono dire la
                  // stessa cosa e non si assomigliano si leggono come due cose
                  // diverse. Senza bordo perche' qui sta su un fondo pulito,
                  // non sopra un'icona.
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: CountDot(count: waiting, withBorder: false),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: texts.labelSmall?.copyWith(
                color: onTap == null
                    ? palette.textFaint
                    : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La griglia degli scatti.
///
/// Tre colonne, due pixel di distanza, quadrati: la stessa griglia che ha
/// qualunque raccolta di foto, e va bene che sia cosi'. Qui l'interfaccia non ha
/// niente da aggiungere — sopra ogni foto sta solo il numero di fiamme che ha
/// preso, perche' e' l'unica cosa che distingue uno scatto dall'altro.
class _EntryGrid extends StatelessWidget {
  const _EntryGrid({required this.entries});

  final List<ChallengeEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        return MediaTap(
          // **Un tocco apre il contenuto**, non la gara. Nel quadrato di due
          // dita della griglia non si vede niente e un video non si sente
          // nemmeno: quello che si e' venuti a rivedere e' la foto grande. Da
          // li' la gara resta a un tocco, scritta sotto.
          onTap: () =>
              FullscreenMedia.open(context, entries: entries, entry: entry),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaFrame(
                url: entry.previewUrl,
                video: entry.isVideo,
                aspectRatio: 1,
                radius: AppRadius.media,
                caption: entry.challengeTitle,
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: _FireBadge(votes: entry.votes, winner: entry.isWinner),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Il conteggio delle fiamme sopra una foto.
///
/// Bianco su un velo scuro, non rosso: sotto c'e' una foto qualunque, e il rosso
/// su un'immagine rossa sparirebbe. La leggibilita' qui viene prima della
/// coerenza cromatica.
class _FireBadge extends StatelessWidget {
  const _FireBadge({required this.votes, required this.winner});

  final int votes;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x8C000000),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            winner ? Icons.emoji_events : Icons.local_fire_department,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            '$votes',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Il messaggio quando una sezione non ha ancora niente dentro.
///
/// Dice **cosa ci finira'**, non "nessun risultato": una sezione vuota che
/// spiega come si riempie e' un invito, una che constata il vuoto e' una porta
/// chiusa.
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: EmptyState(title: title, message: message),
    );
  }
}

/// Apre il foglio con cui si cambiano biografia e citta'.
///
/// **Sta fuori da qualunque widget**, e serve: il comando che la apre si e'
/// spostato dal corpo del profilo alla barra in cima, che e' un altro pezzo
/// dell'albero. Una funzione libera la possono chiamare tutti e due senza che
/// nessuno debba passare l'altro un riferimento a se stesso.
Future<void> editProfile(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) async {
  final bio = TextEditingController(text: profile.bio);

  final saved = await ModalSheet.show<bool>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'Il tuo profilo',
      confirmLabel: 'Salva',
      onConfirm: () => Navigator.of(sheetContext).pop(true),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bio,
              maxLength: OnboardingValidators.bioMaxLength,
              decoration: const InputDecoration(
                labelText: 'UNA RIGA SU DI TE',
                hintText: 'Faccio cose assurde.',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (saved ?? false) {
    await ref
        .read(profileEditControllerProvider.notifier)
        .updateDetails(profile, bio: bio.text);
  }

  bio.dispose();
}
