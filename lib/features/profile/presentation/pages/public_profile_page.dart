import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/media_gestures.dart';
import 'package:crasy/core/widgets/photo_viewer.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/caption_frame.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/payments/presentation/widgets/wallet_card.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/widgets/profile_shelf.dart';
import 'package:crasy/features/profile/presentation/widgets/trophy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il profilo di qualcun altro.
///
/// Mostra le stesse quattro cose del proprio — scatti, vinte, vinti, amici — e
/// non una di piu'. Niente eta', niente citta' di residenza precisa, niente
/// elenco di cosa ha votato: **un profilo pubblico dice cosa uno ha fatto, non
/// chi e'**.
///
/// Ci si arriva da ogni foto e da ogni challenge, ed e' voluto: qui le persone
/// si incontrano guardando quello che combinano, non cercandosi per nome.
class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: AppBackground(
        child: profileState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: EmptyState(
              title: 'Profilo non disponibile',
              message: 'Non riusciamo a leggerlo. Riprova tra poco.',
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: EmptyState(
                  title: 'Profilo non trovato',
                  message: 'Questa persona non c\'e\' piu\'.',
                ),
              );
            }

            return _Body(profile: profile);
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  ProfileShelf _shelf = ProfileShelf.live;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final palette = context.palette;
    final texts = context.texts;
    final entries =
        ref.watch(entriesOfProvider(profile.id)).valueOrNull ?? const [];
    final friends =
        ref.watch(friendsOfProvider(profile.id)).valueOrNull ?? const [];
    final prizeCents = ref.watch(prizeCentsOfProvider(profile.id));
    final wins = entries.where((entry) => entry.isWinner).length;
    final liveChallenges =
        ref.watch(liveChallengesProvider).valueOrNull ?? const <Challenge>[];
    final shown = liveEntries(
      entries,
      liveChallenges.map((challenge) => challenge.id).toSet(),
    );
    final trophies =
        ref.watch(trophiesOfProvider(profile.id)).valueOrNull ?? const [];
    final commissions =
        ref.watch(commissionsOfProvider(profile.id)).valueOrNull ?? const [];

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              _Avatar(profile: profile),
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
              const SizedBox(height: AppSpacing.lg),
              _FriendshipAction(profile: profile),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Quanto ha vinto, in grande e per chiunque.
        //
        // **E' il numero che rende credibile tutta l'app.** Chi arriva da un
        // link e non ha mai sentito nominare CRASY non ha nessun motivo di
        // credere che qui si vincano dei soldi veri; vedere che una persona
        // vera ne ha presi e' l'unica prova che si possa mostrare. Per questo
        // sta sul profilo di tutti e non solo sul proprio.
        //
        // E' il **totale vinto**, non quello che ha ancora da parte: quanti
        // soldi uno tenga sul conto adesso non e' affare di nessuno, e
        // scenderebbe ogni volta che preleva — cioe' proprio quando la
        // promessa e' stata mantenuta meglio.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: PrizeTotalCard(prizeCents: prizeCents),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Stats(entries: entries.length, wins: wins, friends: friends.length),
        const SizedBox(height: AppSpacing.xl),
        ProfileShelfTabs(
          selected: _shelf,
          onPick: (shelf) => setState(() => _shelf = shelf),
        ),
        switch (_shelf) {
          ProfileShelf.live =>
            shown.isEmpty
                ? const _EmptyShelf(
                    title: 'Non e\' in nessuna gara',
                    message:
                        'Quando partecipa a una challenge aperta lo vedi qui.',
                  )
                : _EntryGrid(entries: shown),
          ProfileShelf.trophies =>
            trophies.isEmpty
                ? const _EmptyShelf(
                    title: 'Non ha ancora vinto',
                    message: 'Le foto con cui vince restano qui.',
                  )
                : TrophyGrid(challenges: trophies, kind: TrophyKind.won),
          ProfileShelf.commissioned =>
            commissions.isEmpty
                ? const _EmptyShelf(
                    title: 'Non ha ancora fatto fare niente',
                    message:
                        'Qui trovi le challenge che ha lanciato: quelle ancora '
                        'aperte, in cui puoi entrare adesso, e le foto che ha '
                        'fatto fare mettendo dei soldi in palio.',
                  )
                : CommissionedShelf(challenges: commissions),
        },
      ],
    );
  }
}

/// Il comando dell'amicizia: uno solo, e dice esattamente a che punto siamo.
class _FriendshipAction extends ConsumerWidget {
  const _FriendshipAction({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final status =
        ref.watch(friendshipStatusProvider(profile.id)).valueOrNull ??
        FriendshipStatus.none;
    final actions = ref.read(friendActionsProvider);

    switch (status) {
      case FriendshipStatus.self:
        return const SizedBox.shrink();

      case FriendshipStatus.none:
        return CrasyButton(
          label: 'Aggiungi',
          onPressed: () => actions.send(profile.id),
        );

      case FriendshipStatus.requestSent:
        return SecondaryButton(
          label: 'Richiesta mandata',
          icon: Icons.schedule_rounded,
          onPressed: () => actions.cancel(profile.id),
        );

      case FriendshipStatus.requestReceived:
        return CrasyButton(
          label: 'Accetta',
          onPressed: () => actions.accept(
            FriendRequest(
              fromUserId: profile.id,
              fromUsername: profile.username,
            ),
          ),
        );

      case FriendshipStatus.friends:
        return Row(
          children: [
            Icon(Icons.check_rounded, size: 16, color: palette.accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Siete amici',
              style: context.texts.labelLarge?.copyWith(color: palette.accent),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => actions.remove(profile.id),
              child: Text(
                'Togli',
                style: context.texts.titleMedium?.copyWith(
                  color: palette.textFaint,
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final UserProfile profile;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photoUrl;

    final tondo = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        width: _size,
        height: _size,
        child: profile.hasPhoto
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _Initials(profile: profile),
              )
            : _Initials(profile: profile),
      ),
    );

    // **Senza foto non c'e' niente da ingrandire.** Le iniziali su fondo grigio
    // a tutto schermo sono una schermata vuota che si e' aperta da sola, e chi
    // l'ha aperta pensa di aver rotto qualcosa.
    if (!profile.hasPhoto) {
      return tondo;
    }

    return GestureDetector(
      onTap: () => showPhotoViewer(
        context,
        url: photoUrl!,
        caption: '@${profile.username}',
      ),
      behavior: HitTestBehavior.opaque,
      child: tondo,
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

/// I tre numeri di un profilo pubblico. I soldi stanno sopra, in grande, e non
/// si ripetono qui: lo stesso numero scritto due volte nella stessa schermata
/// non e' un rinforzo, e' il dubbio che siano due numeri diversi.
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
            style: texts.headlineSmall,
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
          // Un tocco apre il contenuto grande, come nel proprio profilo.
          onTap: () =>
              FullscreenMedia.open(context, entries: entries, entry: entry),
          child: CaptionFrame(
            text: entry.caption,
            child: MediaFrame(
              url: entry.mediaUrl,
              video: entry.isVideo,
              aspectRatio: 1,
              radius: AppRadius.xs,
              caption: entry.challengeTitle,
            ),
          ),
        );
      },
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
