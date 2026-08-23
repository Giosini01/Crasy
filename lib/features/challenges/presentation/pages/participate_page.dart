import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/controllers/participation_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Partecipare: scatta, guarda, manda.
///
/// Tre passi e nessuna decorazione in mezzo. Non c'e' un titolo da scrivere,
/// non ci sono filtri, non c'e' una didascalia: il contenuto e' la foto, e ogni
/// campo in piu' fra lo scatto e l'invio e' una partecipazione persa.
///
/// Due regole, e sono quelle che rendono la gara una gara: **si scatta sul
/// momento**, niente galleria, e **si manda una foto sola**, senza ripensamenti.
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
    final myEntry = ref.watch(myEntryForChallengeProvider(widget.challengeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Partecipa')),
      body: AppBackground(
        child: challengeState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const _Notice(
            title: 'Challenge non disponibile',
            message: 'Non riusciamo a caricarla. Riprova tra poco.',
          ),
          data: (challenge) {
            if (challenge == null) {
              return const _Notice(
                title: 'Challenge non trovata',
                message: 'Questa challenge non esiste piu\'.',
              );
            }

            if (challenge.hasEndedAt(DateTime.now())) {
              return const _Notice(
                title: 'Tempo scaduto',
                message:
                    'Questa challenge si e\' chiusa. Guarda chi ha vinto o '
                    'scegline un\'altra.',
              );
            }

            // Chi ha lanciato la challenge non ci partecipa: mette lui i soldi
            // del premio, e una gara in cui chi paga puo' anche vincere non e'
            // una gara.
            if (ref.watch(isMyChallengeProvider(widget.challengeId))) {
              return const _Notice(
                title: 'E\' la tua challenge',
                message:
                    'Il premio lo metti tu, quindi non puoi correre per '
                    'vincerlo. Guarda cosa manda la gente e chi sta in testa.',
              );
            }

            // Chi ha gia' mandato la sua foto non vede nemmeno la fotocamera:
            // il limite si spiega prima, non dopo lo scatto.
            if (myEntry != null) {
              return const _Notice(
                title: 'Hai gia\' partecipato',
                message:
                    'Si manda una foto sola per challenge, e la tua e\' gia\' '
                    'in gara. La trovi nel feed insieme a quelle degli altri.',
              );
            }

            return _Form(
              challenge: challenge,
              media: _media,
              error: _error,
              submitting: submitting,
              onCapture: () => _capture(challenge.mediaKind),
              onSubmit: () => _submit(challenge),
              onClear: () => setState(() => _media = null),
            );
          },
        ),
      ),
    );
  }

  Future<void> _capture(MediaKind kind) async {
    setState(() => _error = null);

    try {
      final media = await ref
          .read(participationControllerProvider.notifier)
          .capture(kind);

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
    messenger.showSnackBar(const SnackBar(content: Text('Sei in gara.')));
  }
}

/// Un messaggio a tutta pagina, con il margine laterale delle altre schermate.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.message});

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

class _Form extends StatelessWidget {
  const _Form({
    required this.challenge,
    required this.media,
    required this.error,
    required this.submitting,
    required this.onCapture,
    required this.onSubmit,
    required this.onClear,
  });

  final Challenge challenge;
  final PickedMedia? media;
  final String? error;
  final bool submitting;
  final VoidCallback onCapture;
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
          SecondaryButton(
            label: challenge.mediaKind.action,
            icon: challenge.mediaKind.isVideo
                ? Icons.videocam_outlined
                : Icons.photo_camera_outlined,
            onPressed: onCapture,
          )
        else
          _Preview(media: picked, kind: challenge.mediaKind, onRetake: onClear),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(message: error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        CrasyButton(
          label: 'Manda in gara',
          loading: submitting,
          onPressed: picked == null ? null : onSubmit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          challenge.mediaKind.isVideo
              ? 'Si registra sul momento, niente galleria. Al massimo '
                    '${MediaKind.maxVideoDuration.inSeconds} secondi, un video '
                    'solo a testa, e una volta mandato non si cambia.'
              : 'Si scatta sul momento, niente galleria. Una foto sola a testa, '
                    'e una volta mandata non si cambia.',
          style: texts.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        // **Chi manda una cosa in gara ha diritto di sapere che ne sara'.**
        //
        // Prima non c'era scritto da nessuna parte: si mandava una foto fatta
        // adesso, per dei soldi veri, senza una riga che dicesse di chi resta e
        // dove finira'. Non e' un cavillo — e' la stessa cosa che ci si aspetta
        // da chiunque ci chieda di consegnargli qualcosa che abbiamo fatto noi.
        //
        // Quello che dice e' il minimo vero: **l'opera resta di chi l'ha
        // fatta**, e CRASY puo' mostrarla dentro l'app e raccontare com'e'
        // finita la gara. Niente di piu': nessuna pubblicita', nessuna vendita,
        // nessun uso fuori da qui.
        //
        // Le parole esatte vanno riviste da un legale prima di aprire al
        // pubblico — vedi `legale.md`. Averle sbagliate e' meglio che non
        // averle affatto, ma va sistemato prima che qualcuno ci metta dei soldi
        // veri.
        Text(
          challenge.mediaKind.isVideo
              ? 'Il video resta tuo. Mandandolo, CRASY puo\' mostrarlo qui '
                    'dentro e usarlo per raccontare com\'e\' finita questa '
                    'challenge.'
              : 'La foto resta tua. Mandandola, CRASY puo\' mostrarla qui '
                    'dentro e usarla per raccontare com\'e\' finita questa '
                    'challenge.',
          style: texts.bodySmall?.copyWith(color: palette.textFaint),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.media,
    required this.kind,
    required this.onRetake,
  });

  final PickedMedia media;
  final MediaKind kind;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            // `Image.memory` e non `MediaFrame`: qui il contenuto non e' ancora
            // salito da nessuna parte, esiste solo come byte in memoria.
            //
            // Del video non si vede l'anteprima ma una conferma: riprodurre un
            // file locale vuole strade diverse su telefono e su web, e non vale
            // la complicazione per i due secondi che sta li'.
            child: media.isVideo
                ? const _VideoReady()
                : Image.memory(media.bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Rifare lo scatto prima di mandarlo si puo': il patto e' che non si
        // cambia **dopo** l'invio, quando la gara e' gia' cominciata.
        TextButton(
          onPressed: onRetake,
          child: Text(kind.isVideo ? 'Registra di nuovo' : 'Scatta di nuovo'),
        ),
      ],
    );
  }
}

/// Il video registrato, pronto per partire.
///
/// Non e' un'anteprima: e' una conferma. Riprodurre un file che sta ancora sul
/// telefono richiede strade diverse su mobile e su web, e per i due secondi che
/// passano fra la registrazione e l'invio non vale la complicazione.
class _VideoReady extends StatelessWidget {
  const _VideoReady();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      color: palette.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 44,
            color: palette.textFaint,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'VIDEO PRONTO',
            style: context.texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
        ],
      ),
    );
  }
}
