import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/presentation/controllers/participation_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Partecipare: scatta o scegli, guarda, manda.
///
/// Tre passi e nessuna decorazione in mezzo. Non c'e' un titolo da scrivere,
/// non ci sono filtri, non c'e' una didascalia: il contenuto e' la foto, e ogni
/// campo in piu' fra lo scatto e l'invio e' una partecipazione persa.
class ParticipatePage extends ConsumerStatefulWidget {
  const ParticipatePage({required this.challengeId, super.key});

  final String challengeId;

  @override
  ConsumerState<ParticipatePage> createState() => _ParticipatePageState();
}

class _ParticipatePageState extends ConsumerState<ParticipatePage> {
  PickedMedia? _media;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final challengeState = ref.watch(challengeProvider(widget.challengeId));
    final submitting = ref.watch(participationControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Partecipa')),
      body: AppBackground(
        child: challengeState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const EmptyState(
            title: 'Challenge non disponibile',
            message: 'Non riusciamo a caricarla. Riprova tra poco.',
          ),
          data: (challenge) {
            if (challenge == null) {
              return const EmptyState(
                title: 'Challenge non trovata',
                message: 'Questa challenge non esiste piu\'.',
              );
            }

            if (challenge.hasEndedAt(DateTime.now())) {
              return const EmptyState(
                title: 'Tempo scaduto',
                message:
                    'Questa challenge si e\' chiusa. Guarda chi ha vinto o '
                    'scegline un\'altra.',
              );
            }

            return _Form(
              challenge: challenge,
              media: _media,
              error: _error,
              submitting: submitting,
              onPick: _pick,
              onSubmit: () => _submit(challenge),
              onClear: () => setState(() => _media = null),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);

    try {
      final media = await ref
          .read(participationControllerProvider.notifier)
          .pick(source);

      // Rinunciare a scattare non e' un errore: se l'utente chiude la
      // fotocamera non deve trovarsi un messaggio rosso in pagina.
      if (media == null || !mounted) {
        return;
      }

      setState(() => _media = media);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = ErrorMessageMapper.map(error));
      }
    }
  }

  Future<void> _submit(Challenge challenge) async {
    final media = _media;

    if (media == null) {
      return;
    }

    setState(() => _error = null);

    final sent = await ref
        .read(participationControllerProvider.notifier)
        .submit(challengeId: challenge.id, media: media);

    if (!mounted) {
      return;
    }

    if (!sent) {
      final error = ref.read(participationControllerProvider).error;

      setState(() {
        _error = error == null
            ? 'Invio non riuscito. Riprova.'
            : ErrorMessageMapper.map(error);
      });

      return;
    }

    // Il messaggero si prende **prima** di chiudere la pagina: dopo il pop
    // questo contesto e' gia' staccato dall'albero e non saprebbe piu' trovarlo.
    final messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Partecipazione inviata.')),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.challenge,
    required this.media,
    required this.error,
    required this.submitting,
    required this.onPick,
    required this.onSubmit,
    required this.onClear,
  });

  final Challenge challenge;
  final PickedMedia? media;
  final String? error;
  final bool submitting;
  final void Function(ImageSource source) onPick;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final picked = media;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          challenge.prizeLabel,
          style: texts.displaySmall?.copyWith(color: palette.accent),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(challenge.title.toUpperCase(), style: texts.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(challenge.brief, style: texts.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        if (picked == null)
          _Chooser(onPick: onPick)
        else
          _Preview(media: picked, onClear: onClear),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(message: error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        CrasyButton(
          label: 'Invia la partecipazione',
          loading: submitting,
          onPressed: picked == null ? null : onSubmit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Una sola foto a testa. Puoi sostituirla finche\' la challenge e\' '
          'aperta.',
          style: texts.bodySmall,
        ),
      ],
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser({required this.onPick});

  final void Function(ImageSource source) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SecondaryButton(
          label: 'Scatta ora',
          icon: Icons.photo_camera_outlined,
          onPressed: () => onPick(ImageSource.camera),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'Scegli dalla galleria',
          icon: Icons.image_outlined,
          onPressed: () => onPick(ImageSource.gallery),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.media, required this.onClear});

  final PickedMedia media;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            // `Image.memory` e non `MediaFrame`: qui la foto non e' ancora
            // salita da nessuna parte, esiste solo come byte in memoria.
            child: Image.memory(media.bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: onClear, child: const Text('Cambia foto')),
      ],
    );
  }
}
