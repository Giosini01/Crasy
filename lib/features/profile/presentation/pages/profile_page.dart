import 'package:app_incontri/core/errors/error_message_mapper.dart';
import 'package:app_incontri/core/services/location_service.dart';
import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/core/widgets/app_card.dart';
import 'package:app_incontri/core/widgets/brand_mark.dart';
import 'package:app_incontri/core/widgets/inline_banner.dart';
import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:app_incontri/features/auth/presentation/controllers/auth_action_controller.dart';
import 'package:app_incontri/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:app_incontri/features/profile/domain/entities/profile_interests.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/presentation/controllers/profile_edit_controller.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:app_incontri/features/profile/presentation/widgets/interests_picker.dart';
import 'package:app_incontri/features/stats/domain/entities/vibe_stats.dart';
import 'package:app_incontri/features/stats/presentation/providers/stats_providers.dart';
import 'package:app_incontri/features/stats/presentation/widgets/vibe_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentUserProfileProvider);

    return profileState.when(
      loading: () => const PlaceholderPageScaffold(
        eyebrow: 'Profilo',
        icon: Icons.hourglass_empty_rounded,
        title: 'Stiamo recuperando il tuo profilo.',
        description: 'Ancora un istante.',
      ),
      error: (_, _) => const PlaceholderPageScaffold(
        eyebrow: 'Profilo',
        icon: Icons.cloud_off_rounded,
        title: 'Non siamo riusciti a leggere il profilo.',
        description: 'Riprova piu tardi.',
      ),
      data: (profile) {
        if (profile == null) {
          return const PlaceholderPageScaffold(
            eyebrow: 'Profilo',
            icon: Icons.person_off_outlined,
            title: 'Profilo non disponibile.',
            description: 'Completa l\'onboarding per vedere qui i tuoi dati.',
          );
        }

        return _ProfileView(profile: profile);
      },
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final age = AppDateUtils.calculateAge(profile.birthDate);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EyebrowLabel('Profilo'),
                    const SizedBox(height: AppSpacing.md),
                    // Foto, nome ed eta' sulla stessa riga: e' la carta
                    // d'identita' della pagina, e occupa lo spazio di una riga
                    // invece di tre.
                    Row(
                      children: [
                        _Avatar(profile: profile),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: context.texts.headlineMedium,
                              ),
                              Text(
                                '$age anni',
                                style: context.texts.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _PhotoStatusNote(profile: profile),
                    const SizedBox(height: AppSpacing.md),
                    _InterestsSection(profile: profile),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Mi identifico come',
                            value: profile.gender.label,
                          ),
                          Divider(color: palette.border, height: 1),
                          _InfoRow(
                            icon: Icons.favorite_border_rounded,
                            label: 'Voglio conoscere',
                            value: profile.interestedIn.label,
                          ),
                          Divider(color: palette.border, height: 1),
                          _InfoRow(
                            icon: Icons.cake_outlined,
                            label: 'Compleanno',
                            value: AppDateUtils.formatItalianDate(
                              profile.birthDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _LocationRow(profile: profile),
                    const SizedBox(height: AppSpacing.md),
                    // Il diario chiude la pagina: viene dopo chi sei, non
                    // prima. E' un consuntivo, non una presentazione.
                    const _DiarySection(),
                    const SizedBox(height: AppSpacing.md),
                    const _PrivacyNote(),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(authActionControllerProvider.notifier)
                            .signOut();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.danger,
                        side: BorderSide(
                          color: palette.danger.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('Logout'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quello che resta delle giornate passate.
///
/// Le foto durano un giorno e poi spariscono davvero; questi numeri no. E'
/// voluto: e' il modo di dire che quello che si e' mostrato non resta a giro
/// per sempre, ma quello che e' successo si puo' ancora guardare.
///
/// **Non e' una classifica.** Niente "sei piu' bello del 73%": un'app che
/// chiede di farsi vedere com'e' non puo' poi mettere le persone in fila.
class _DiarySection extends ConsumerWidget {
  const _DiarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final lifetime = ref.watch(lifetimeVibeProvider).valueOrNull ?? VibeLifetime.empty;
    final streak = ref.watch(streakProvider);

    if (lifetime.totalDailies == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const EyebrowLabel('Il tuo diario'),
              StreakBadge(days: streak),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          VibeDayRow(
            day: VibeDay(
              views: lifetime.totalViews,
              likes: lifetime.totalLikes,
              matches: lifetime.totalMatches,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _story(lifetime),
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Una riga che racconta, invece di elencare.
  ///
  /// Gli stessi numeri di sopra detti a parole: e' la differenza fra un
  /// cruscotto e una cosa che fa piacere leggere.
  static String _story(VibeLifetime lifetime) {
    final days = lifetime.totalDailies;
    final giorni = days == 1 ? 'volta' : 'volte';

    if (lifetime.totalMatches > 0) {
      final persone = lifetime.totalMatches == 1 ? 'persona' : 'persone';

      return 'Ti sei fatto vedere $days $giorni, e hai conosciuto '
          '${lifetime.totalMatches} nuove $persone.';
    }

    if (lifetime.totalLikes > 0) {
      return 'Ti sei fatto vedere $days $giorni, e in ${lifetime.totalLikes} '
          'ci hanno messo il cuore.';
    }

    return 'Ti sei fatto vedere $days $giorni. Il resto viene da se.';
  }
}

/// Che fine ha fatto la foto profilo appena caricata.
///
/// Senza questa riga il rifiuto era **muto**: si sceglieva una foto, il server
/// non ci trovava un volto, la cancellava, e sullo schermo restava l'iniziale
/// come se il caricamento non fosse mai partito. Chi guardava non aveva modo
/// di capire se fosse un guasto, una foto sbagliata o un'app rotta.
class _PhotoStatusNote extends StatelessWidget {
  const _PhotoStatusNote({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = profile.photoStatus;

    if (status != PhotoStatus.pending && status != PhotoStatus.rejected) {
      return const SizedBox.shrink();
    }

    final rejected = status == PhotoStatus.rejected;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
            size: 16,
            color: rejected ? palette.danger : palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              rejected
                  ? 'Nella foto non abbiamo riconosciuto un volto, quindi non '
                        'e stata salvata. Tocca il cerchio e scegline una in '
                        'cui si veda la faccia.'
                  : 'Stiamo controllando la foto: comparira fra poco.',
              style: context.texts.bodySmall?.copyWith(
                color: rejected ? palette.danger : palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La foto profilo, con l'iniziale come ripiego.
///
/// Toccandola si sceglie da dove prenderla. La foto profilo e' permanente e
/// serve a farsi riconoscere; e' una cosa diversa dall'Istantanea del giorno,
/// e per questo qui la galleria e' ammessa.
class _Avatar extends ConsumerWidget {
  const _Avatar({required this.profile});

  final UserProfile profile;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PhotoSourceSheet(),
    );

    if (source == null) {
      return;
    }

    await ref
        .read(profileEditControllerProvider.notifier)
        .pickAndUploadPhoto(profile, source);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final name = profile.name.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return GestureDetector(
      onTap: () => _change(context, ref),
      child: Stack(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.brandTint,
              shape: BoxShape.circle,
            ),
            child: profile.hasPhoto
                ? Image.network(
                    profile.photoUrl!,
                    fit: BoxFit.cover,
                    width: 76,
                    height: 76,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (context, _, _) => Text(
                      initial,
                      style: context.texts.displaySmall?.copyWith(
                        color: palette.brand,
                      ),
                    ),
                  )
                : Text(
                    initial,
                    style: context.texts.displaySmall?.copyWith(
                      color: palette.brand,
                    ),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              decoration: BoxDecoration(
                color: palette.brand,
                shape: BoxShape.circle,
                border: Border.all(color: palette.background, width: 2),
              ),
              child: Icon(
                profile.photoStatus == PhotoStatus.pending
                    ? Icons.hourglass_top_rounded
                    : Icons.photo_camera_rounded,
                size: 13,
                color: palette.onBrand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scelta della provenienza della foto profilo.
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text('Foto profilo', style: context.texts.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta ora'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: context.texts.bodyMedium)),
          Text(value, style: context.texts.titleMedium),
        ],
      ),
    );
  }
}

/// Interessi e rompighiaccio, con le azioni per cambiarli.
///
/// Gli interessi non sono decorativi: da loro nasce la percentuale di
/// affinita' che le altre persone vedono sulla tua scheda.
class _InterestsSection extends ConsumerWidget {
  const _InterestsSection({required this.profile});

  final UserProfile profile;

  Future<void> _editInterests(BuildContext context, WidgetRef ref) async {
    final updated = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        fullscreenDialog: true,
        builder: (context) => _InterestsEditorPage(initial: profile.interests),
      ),
    );

    if (updated == null) {
      return;
    }

    await ref
        .read(profileEditControllerProvider.notifier)
        .updateInterests(profile, updated);
  }

  Future<void> _editIcebreaker(BuildContext context, WidgetRef ref) async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (context) => _IcebreakerEditorPage(initial: profile.icebreaker),
      ),
    );

    if (updated == null) {
      return;
    }

    await ref
        .read(profileEditControllerProvider.notifier)
        .updateIcebreaker(profile, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Interessi', style: context.texts.labelSmall)),
            TextButton(
              onPressed: () => _editInterests(context, ref),
              child: Text(profile.interests.isEmpty ? 'Scegli' : 'Modifica'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        if (profile.interests.isEmpty)
          Text(
            'Senza interessi non possiamo calcolare l affinita con nessuno.',
            style: context.texts.bodyMedium,
          )
        else
          InterestChips(ids: profile.interests),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text('Oggi...', style: context.texts.labelSmall),
            ),
            TextButton(
              onPressed: () => _editIcebreaker(context, ref),
              child: Text(profile.hasIcebreaker ? 'Modifica' : 'Scrivilo'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          profile.hasIcebreaker
              ? profile.icebreaker
              : 'Cosa stai facendo oggi. Compare sulla tua Istantanea.',
          style: context.texts.bodyLarge?.copyWith(
            color: profile.hasIcebreaker
                ? palette.textPrimary
                : palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InterestsEditorPage extends StatefulWidget {
  const _InterestsEditorPage({required this.initial});

  final List<String> initial;

  @override
  State<_InterestsEditorPage> createState() => _InterestsEditorPageState();
}

class _InterestsEditorPageState extends State<_InterestsEditorPage> {
  late List<String> _selected = widget.initial;

  bool get _canSave => _selected.length >= ProfileInterests.minChoices;

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: 'I tuoi interessi',
      // Sotto il minimo la percentuale non direbbe nulla, quindi non si salva.
      onConfirm: _canSave
          ? () => Navigator.of(context).pop(_selected)
          : null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: InterestsPicker(
          selected: _selected,
          onChanged: (value) => setState(() => _selected = value),
        ),
      ),
    );
  }
}

class _IcebreakerEditorPage extends StatefulWidget {
  const _IcebreakerEditorPage({required this.initial});

  final String initial;

  @override
  State<_IcebreakerEditorPage> createState() => _IcebreakerEditorPageState();
}

class _IcebreakerEditorPageState extends State<_IcebreakerEditorPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorScaffold(
      title: 'Oggi...',
      onConfirm: () => Navigator.of(context).pop(_controller.text.trim()),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLength: OnboardingValidators.icebreakerMaxLength,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'mi trovi sul divano a riguardare Harry Potter',
              ),
            ),
            Text(
              'Una riga sola. Piu\' e precisa, piu\' e facile che qualcuno ti '
              'scriva proprio di quello.',
              style: context.texts.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Impalcatura comune delle pagine di modifica: annulla, titolo, salva.
///
/// A schermo intero e non in un foglio: la tastiera copre meta' schermo, e un
/// foglio che le sta sopra spinge il campo fuori dalla vista.
class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.child,
    required this.onConfirm,
  });

  final String title;
  final Widget child;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.texts.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: onConfirm,
                      child: Text(
                        'Salva',
                        style: context.texts.labelLarge?.copyWith(
                          color: onConfirm == null
                              ? palette.textSecondary
                              : palette.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: palette.border, height: 0.5, thickness: 0.5),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
/// Stato della posizione, con l'azione per impostarla o rinfrescarla.
///
/// Senza coordinate il profilo e' invisibile al feed, quindi la mancanza va
/// segnalata come un problema da risolvere, non nascosta.
class _LocationRow extends ConsumerWidget {
  const _LocationRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final action = ref.watch(profileEditControllerProvider);
    final isBusy = action.isLoading;
    final hasLocation = profile.hasLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: hasLocation ? palette.surfaceMuted : palette.brandTint,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: hasLocation ? Colors.transparent : palette.brand,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasLocation
                    ? Icons.my_location_rounded
                    : Icons.location_off_rounded,
                size: 18,
                color: hasLocation ? palette.textSecondary : palette.brand,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasLocation
                      ? 'Posizione impostata, arrotondata a circa un '
                            'chilometro.'
                      : 'Senza posizione non entri nel Per Te di nessuno.',
                  style: context.texts.bodySmall?.copyWith(
                    color: hasLocation ? palette.textSecondary : palette.brand,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: isBusy
              ? null
              : () => ref
                    .read(profileEditControllerProvider.notifier)
                    .refreshLocation(profile),
          icon: isBusy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(
            isBusy
                ? 'Cerco la posizione...'
                : hasLocation
                ? 'Aggiorna la posizione'
                : 'Imposta la posizione',
          ),
        ),
        if (action.hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          InlineBanner(message: _describe(action.error!)),
        ],
      ],
    );
  }

  static String _describe(Object error) {
    if (error is LocationException) {
      return error.message;
    }

    return ErrorMessageMapper.map(error);
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Nessuna foto permanente, nessuna vetrina pubblica.',
              style: context.texts.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

