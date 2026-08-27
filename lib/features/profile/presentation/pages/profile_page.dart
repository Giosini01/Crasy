import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
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
import 'package:crasy/features/legal/presentation/widgets/privacy_settings.dart';
import 'package:crasy/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:crasy/features/payments/presentation/widgets/wallet_card.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/controllers/profile_edit_controller.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:crasy/features/profile/presentation/widgets/delete_account.dart';
import 'package:crasy/features/profile/presentation/widgets/profile_shelf.dart';
import 'package:crasy/features/profile/presentation/widgets/trophy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              const CrasyHeaderBar(),
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
                                        'Lancia una challenge: la foto che sceglierai come '
                                        'vincitrice resta qui, ed e\' roba che hai fatto fare tu.',
                                  )
                                : TrophyGrid(
                                    challenges: commissions,
                                    kind: TrophyKind.commissioned,
                                  ),
                        },
                        const SizedBox(height: AppSpacing.xl),
                        // **La porta per revocare sta accanto a quella per
                        // uscire**, non sepolta in un menu: il GDPR chiede che
                        // togliere un consenso sia facile quanto darlo, e
                        // "facile" vuol dire trovabile senza cercare.
                        // **Questa resta, e non e' una dimenticanza.**
                        //
                        // Il regolamento europeo chiede che revocare un
                        // consenso sia facile quanto darlo: se per darlo basta
                        // una spunta e per toglierlo bisogna scrivere una mail,
                        // quel consenso non e' mai stato libero — e cade,
                        // trascinandosi dietro il trattamento che reggeva.
                        //
                        // E' piccola e grigia, non una voce di menu: c'e' per
                        // chi la cerca, non per chi sta guardando le proprie
                        // foto.
                        Center(
                          child: TextButton(
                            onPressed: () => showPrivacySettings(context),
                            child: Text(
                              'Privacy e consensi',
                              style: context.texts.bodySmall?.copyWith(
                                color: palette.textFaint,
                              ),
                            ),
                          ),
                        ),
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
                        // Staccata dalle altre e rossa. **E' l'unica voce di
                        // questa schermata che non si disfa**, e deve
                        // sembrarlo: messa in fila con "Esci", prima o poi
                        // qualcuno la tocca al posto suo.
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: TextButton(
                            onPressed: () => showDeleteAccount(context),
                            child: Text(
                              'Cancella account',
                              style: context.texts.bodySmall?.copyWith(
                                color: palette.accent,
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
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(profile: profile, onTap: () => _changePhoto(context, ref)),
            const Spacer(),
            // La modifica e' un'icona e non un bottone: si usa due volte in
            // tutta la vita del profilo, e un bottone a tutta larghezza qui
            // peserebbe quanto il nome.
            IconButton(
              onPressed: () => _edit(context, ref, profile),
              icon: const Icon(Icons.tune_rounded, size: 20),
              tooltip: 'Modifica profilo',
              color: palette.textFaint,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('@${profile.username}', style: texts.displaySmall),
        if (profile.hasBio) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(profile.bio, style: texts.bodyMedium),
        ],
        if (profile.city.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.city.toUpperCase(),
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
        ],
      ],
    );
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta una foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            // Qui la galleria c'e', a differenza delle challenge: la foto
            // profilo non e' una gara, e obbligare a farsi un selfie sul
            // momento per cambiarla sarebbe una regola senza motivo.
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    await ref
        .read(profileEditControllerProvider.notifier)
        .pickAndUploadPhoto(profile, source);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final bio = TextEditingController(text: profile.bio);
    final city = TextEditingController(text: profile.city);

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
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: city,
                maxLength: OnboardingValidators.cityMaxLength,
                decoration: const InputDecoration(
                  labelText: 'CITTA\'',
                  hintText: 'Napoli',
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
          .updateDetails(profile, bio: bio.text, city: city.text);
    }

    bio.dispose();
    city.dispose();
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
  });

  final int entries;
  final int wins;
  final int friends;

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
              _Stat(label: 'AMICI', value: '$friends'),
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
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: texts.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
        ],
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
                url: entry.mediaUrl,
                video: entry.isVideo,
                aspectRatio: 1,
                radius: AppRadius.xs,
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
