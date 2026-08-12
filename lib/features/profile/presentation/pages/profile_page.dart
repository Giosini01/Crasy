import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/auth/presentation/controllers/auth_action_controller.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/presentation/controllers/profile_edit_controller.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Il profilo: quello che hai fatto, non quello che sei.
///
/// Tre numeri e una griglia di foto. Non c'e' una copertina, non ci sono badge,
/// non c'e' un livello da salire: su CRASY una persona vale le foto che ha
/// mandato e le challenge che ha vinto, ed e' tutto li' sopra.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentUserProfileProvider);
    final entries = ref.watch(myEntriesProvider).valueOrNull ?? const [];
    final wins = ref.watch(myWinsProvider);
    final prizeCents = ref.watch(myPrizeCentsProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: profileState.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: EmptyState(
                title: 'Profilo non disponibile',
                message: 'Non riusciamo a leggere il tuo profilo. Riprova.',
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return const SizedBox.shrink();
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                children: [
                  _Head(profile: profile),
                  const SizedBox(height: AppSpacing.xl),
                  _Stats(
                    entries: entries.length,
                    wins: wins.length,
                    prizeCents: prizeCents,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Divider(color: context.palette.line),
                  const SizedBox(height: AppSpacing.lg),
                  if (entries.isEmpty)
                    const EmptyState(
                      title: 'Ancora niente',
                      message:
                          'Le foto che mandi alle challenge finiscono qui.',
                    )
                  else
                    _EntryGrid(entries: entries),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Head extends ConsumerWidget {
  const _Head({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _changePhoto(context, ref),
          child: _Avatar(profile: profile),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${profile.username}', style: texts.headlineMedium),
              if (profile.hasBio) Text(profile.bio, style: texts.bodyMedium),
              if (profile.city.isNotEmpty)
                Text(
                  profile.city.toUpperCase(),
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _edit(context, ref, profile),
                    child: const Text('Modifica'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(
                    onPressed: () => ref
                        .read(authActionControllerProvider.notifier)
                        .signOut(),
                    child: Text(
                      'Esci',
                      style: texts.titleMedium?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          padding: const EdgeInsets.all(AppSpacing.page),
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
  const _Avatar({required this.profile});

  final UserProfile profile;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    if (profile.hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Image.network(
          profile.photoUrl!,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _Initials(profile: profile),
        ),
      );
    }

    return _Initials(profile: profile);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: _Avatar._size,
      height: _Avatar._size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        profile.initials,
        style: context.texts.titleLarge?.copyWith(color: palette.textSecondary),
      ),
    );
  }
}

/// I tre numeri.
///
/// Sono tre e non otto: partecipazioni, vittorie, premi. Tutto il resto —
/// visualizzazioni, voti ricevuti, giorni di fila — sarebbe roba da far salire
/// per il gusto di farla salire.
class _Stats extends StatelessWidget {
  const _Stats({
    required this.entries,
    required this.wins,
    required this.prizeCents,
  });

  final int entries;
  final int wins;
  final int prizeCents;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Stat(label: 'PARTECIPAZIONI', value: '$entries'),
        _Stat(label: 'VINTE', value: '$wins'),
        _Stat(
          label: 'PREMI',
          value: AppMoney.format(prizeCents),
          color: prizeCents > 0 ? palette.accent : null,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: texts.headlineMedium?.copyWith(color: color),
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
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        return MediaFrame(
          url: entry.mediaUrl,
          aspectRatio: 1,
          radius: AppRadius.xs,
          caption: entry.challengeTitle,
        );
      },
    );
  }
}
