import 'dart:async';

import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/crasy_camera.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/core/widgets/video/local_video_stub.dart'
    if (dart.library.io) 'package:crasy/core/widgets/video/local_video_io.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/controllers/participation_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Partecipare: scatta, guarda, manda.
///
/// Tre passi e nessuna decorazione in mezzo. Non c'e' un titolo da scrivere e
/// non ci sono filtri: il contenuto e' la foto, e ogni campo in piu' fra lo
/// scatto e l'invio e' una partecipazione persa.
///
/// L'unica cosa che si scrive e' la **didascalia**, e non si scrive in un campo:
/// si tocca la foto e si scrive **sopra**. Le lettere compaiono lungo il bordo,
/// a elle — salgono dal centro del lato sinistro, girano l'angolo e proseguono
/// in alto — come la scritta a pennarello sul bianco di una polaroid.
///
/// La differenza da un campo sotto la foto non e' grafica. Una didascalia
/// scritta accanto e' una riga di testo vicino a un'immagine: due cose che si
/// guardano una alla volta. Scritta sul bordo diventa **parte dell'oggetto**, e
/// si legge insieme alla foto invece che dopo.
///
/// Compare solo **dopo** lo scatto, perche' prima non c'e' niente su cui
/// scrivere. E resta facoltativa: la maggior parte delle foto non ha niente da
/// aggiungere.
///
/// Due regole, e sono quelle che rendono la gara una gara.
///
/// La prima: **si manda una cosa sola**, senza ripensamenti.
///
/// La seconda la detta chi ha messo i soldi, e da qui non si aggira. In una
/// missione **istantanea** si scatta sul momento e la galleria non si apre; in
/// una **d'archivio** si prende quello che si ha gia' e la fotocamera non si
/// apre. Non esiste una schermata che chieda da dove prenderla, perche' quella
/// domanda ha gia' una risposta. Vedi `ChallengeSource`.
class ParticipatePage extends ConsumerStatefulWidget {
  const ParticipatePage({required this.challengeId, super.key});

  final String challengeId;

  @override
  ConsumerState<ParticipatePage> createState() => _ParticipatePageState();
}

class _ParticipatePageState extends ConsumerState<ParticipatePage> {
  PickedMedia? _media;
  final _caption = TextEditingController();
  String? _error;

  /// Se la fotocamera e' aperta in questo momento.
  ///
  /// **Serve a spegnere l'anteprima del video, e non e' un dettaglio.** Un
  /// lettore video acceso tiene occupato l'audio del telefono; la fotocamera,
  /// per registrare, ha bisogno del microfono e lo trova gia' preso — e non
  /// parte. E' il motivo per cui "registra di nuovo" non funzionava: la prima
  /// volta l'anteprima non c'era ancora, la seconda si'.
  bool _fotocameraAperta = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

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
                message: 'Questa challenge non esiste più.',
              );
            }

            if (challenge.hasEndedAt(DateTime.now())) {
              return const _Notice(
                title: 'Tempo scaduto',
                message:
                    'Questa challenge si è chiusa. Guarda chi ha vinto o '
                    'scegline un\'altra.',
              );
            }

            // Chi ha lanciato la challenge non ci partecipa: mette lui i soldi
            // del premio, e una gara in cui chi paga puo' anche vincere non e'
            // una gara.
            if (ref.watch(isMyChallengeProvider(widget.challengeId))) {
              return const _Notice(
                title: 'È la tua challenge',
                message:
                    'Il premio lo metti tu, quindi non puoi correre per '
                    'vincerlo. Guarda cosa manda la gente e chi sta in testa.',
              );
            }

            // Chi ha gia' mandato la sua foto non vede nemmeno la fotocamera:
            // il limite si spiega prima, non dopo lo scatto.
            if (myEntry != null) {
              return const _Notice(
                title: 'Hai già partecipato',
                message:
                    'Si manda una foto sola per challenge, e la tua è già '
                    'in gara. La trovi nel feed insieme a quelle degli altri.',
              );
            }

            return _Form(
              challenge: challenge,
              media: _media,
              fotocameraAperta: _fotocameraAperta,
              error: _error,
              submitting: submitting,
              // Sulla sfida del giorno il bottone non si spegne mai: non
              // costa una delle cinque, quindi non c'e' niente da finire.
              outOfLives:
                  !challenge.isDaily && ref.watch(livesLeftProvider) <= 0,
              caption: _caption,
              onCapture: () => _capture(challenge),
              onSubmit: () => _submit(challenge),
              // **Rifare lo scatto riapre la fotocamera, non svuota la
              // pagina.** Prima si tornava a una schermata vuota con il
              // bottone da premere di nuovo: due tocchi per rifare una cosa
              // che si rifa' perche' la prima non andava bene — e nel mezzo
              // la foto scompariva prima che ce ne fosse un'altra.
              //
              // Adesso si riapre direttamente, e quella di prima resta finche'
              // non ne arriva una nuova: chiudere la fotocamera senza scattare
              // non fa perdere niente.
              onRetake: () => _capture(challenge),
            );
          },
        ),
      ),
    );
  }

  Future<void> _capture(Challenge challenge) async {
    // L'anteprima si spegne **prima** che la fotocamera parta, non dopo: il
    // microfono lo si contende all'apertura.
    setState(() {
      _error = null;
      _fotocameraAperta = true;
    });

    final kind = challenge.mediaKind;

    try {
      final controller = ref.read(participationControllerProvider.notifier);

      // **La fotocamera e' la nostra, dove possiamo averla.**
      //
      // Quella di sistema portava dietro un problema che da qui non si
      // aggiustava: su iPhone, con "Immagine speculare fotocamera anteriore"
      // acceso, il selfie viene **salvato specchiato** — e quell'interruttore
      // sta nelle impostazioni del telefono, non nelle nostre. Scattando noi,
      // il file non e' mai specchiato.
      //
      // Sul web resta quella di sistema: li' l'app e' un'anteprima, e il
      // permesso alla fotocamera lo gestisce il browser a modo suo.
      // **In una gara d'archivio la fotocamera non si apre affatto.** Non e'
      // un ripiego: e' la regola della gara. Chi ha messo i soldi ha chiesto
      // una cosa gia' successa, e riscattarla adesso vorrebbe dire mandare
      // un'altra cosa.
      final media = challenge.source.isArchive
          ? await controller.capture(kind, from: ChallengeSource.archive)
          : (CrasyCamera.availableFor(video: kind.isVideo)
                ? await _scattaConLaNostra(controller, kind)
                : await controller.capture(kind));

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
    } finally {
      if (mounted) {
        setState(() => _fotocameraAperta = false);
      }
    }
  }

  /// Apre la fotocamera di CRASY e prepara quello che ne esce.
  Future<PickedMedia?> _scattaConLaNostra(
    ParticipationController controller,
    MediaKind kind,
  ) async {
    final scatto = await CrasyCamera.open(context, video: kind.isVideo);

    // Chiusa senza scattare: non e' un errore e non deve dire niente.
    if (scatto == null || !mounted) {
      return null;
    }

    // Se e' un selfie, la foto viene ribaltata come lo era l'anteprima: quello
    // che si e' visto e' quello che si manda.
    return controller.fromCamera(scatto.file, kind, mirror: scatto.mirrored);
  }

  /// L'ultima domanda prima che lo scatto entri in gara.
  ///
  /// **Non e' una finestra di cortesia.** Qui dentro si spendono due cose che
  /// non tornano indietro: una delle cinque partecipazioni del giorno, e
  /// l'unico scatto che quella gara accettera' da te. Da qui in poi la foto non
  /// si cambia e non si toglie — e' il patto con chi la vota e con gli altri
  /// concorrenti, che altrimenti potrebbero rifare la propria dopo aver visto
  /// le fiamme.
  ///
  /// Nessuno di questi due fatti si vede guardando la schermata, ed e' proprio
  /// il tipo di cosa che si scopre subito dopo averla fatta. Vale l'attimo che
  /// costa.
  Future<bool> _conferma(Challenge challenge) async {
    final palette = context.palette;
    final texts = context.texts;

    final risposta = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'La mandi'),
              TextSpan(
                text: '?',
                style: TextStyle(color: palette.accent),
              ),
            ],
          ),
          style: texts.titleLarge,
        ),
        content: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Hai '),
              TextSpan(
                text: 'un solo scatto',
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text:
                    ' per questa missione: da adesso non si cambia e non si '
                    'cancella.',
              ),
              // Sulla sfida del giorno la seconda meta' della frase e' falsa, e
              // in un avviso che serve a far pensare due volte una frase falsa
              // e' peggio di nessun avviso: quella non toglie niente, e chi la
              // legge deve saperlo prima di rinunciare.
              if (challenge.isDaily) ...[
                const TextSpan(text: ' Ma è la sfida del giorno: '),
                TextSpan(
                  text: 'non ti costa nessuna partecipazione',
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '.'),
              ] else ...[
                const TextSpan(text: ' E ti toglie una delle '),
                TextSpan(
                  text: 'partecipazioni di oggi',
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ],
          ),
          style: texts.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ASPETTA'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('MANDA', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
    );

    return risposta ?? false;
  }

  Future<void> _submit(Challenge challenge) async {
    final media = _media;

    if (media == null) {
      return;
    }

    // La didascalia passa dallo stesso controllo delle consegne: e' testo
    // scritto da una persona e letto da tutte le altre, e non c'e' ragione per
    // cui qui debba valere una regola piu' larga.
    final didascalia = _caption.text.trim();
    final rifiuto = didascalia.isEmpty
        ? null
        : ContentPolicy.validate(didascalia);

    if (rifiuto != null) {
      setState(() => _error = rifiuto);

      return;
    }

    setState(() => _error = null);

    if (!await _conferma(challenge)) {
      return;
    }

    if (!mounted) {
      return;
    }

    final sent = await ref
        .read(participationControllerProvider.notifier)
        .submit(
          challengeId: challenge.id,
          media: media,
          caption: didascalia,
          daily: challenge.isDaily,
        );

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
    required this.fotocameraAperta,
    required this.error,
    required this.submitting,
    required this.outOfLives,
    required this.caption,
    required this.onCapture,
    required this.onSubmit,
    required this.onRetake,
  });

  final Challenge challenge;
  final PickedMedia? media;

  /// Vedi `_ParticipatePageState._fotocameraAperta`.
  final bool fotocameraAperta;
  final String? error;
  final bool submitting;

  /// Vero quando le cinque partecipazioni di oggi sono finite.
  final bool outOfLives;

  /// Le due parole sotto la foto. Vuoto e' il caso normale.
  final TextEditingController caption;
  final VoidCallback onCapture;
  final VoidCallback onSubmit;
  final VoidCallback onRetake;

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
            // **Il bottone dice la verita' su cosa aprira'.** Scritto "scatta"
            // su una gara d'archivio, uno si aspetta la fotocamera e si trova
            // il rullino: e' il tipo di sorpresa che fa chiudere l'app.
            label: challenge.source.isArchive
                ? (challenge.mediaKind.isVideo
                      ? 'Scegli un video'
                      : 'Scegli una foto')
                : challenge.mediaKind.action,
            icon: challenge.source.isArchive
                ? Icons.photo_library_outlined
                : (challenge.mediaKind.isVideo
                      ? Icons.videocam_outlined
                      : Icons.photo_camera_outlined),
            onPressed: onCapture,
          )
        else
          _Preview(
            media: picked,
            kind: challenge.mediaKind,
            source: challenge.source,
            fotocameraAperta: fotocameraAperta,
            caption: caption,
            onRetake: onRetake,
          ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(message: error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        CrasyButton(
          label: 'Manda in gara',
          loading: submitting,
          // **Le cinque di oggi valgono anche qui.** Il bottone si spegne prima
          // che uno scatti, non dopo: far scattare una foto per poi dire che
          // non si puo' mandare e' il modo peggiore di comunicare un limite.
          onPressed: picked == null || outOfLives ? null : onSubmit,
        ),
        if (outOfLives) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hai già partecipato a ${Challenge.livesPerDay} gare oggi. '
            'A mezzanotte ricominci.',
            style: texts.bodySmall?.copyWith(color: palette.accent),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(_laRegola(challenge), style: texts.bodySmall),
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
              ? 'Il video resta tuo. Mandandolo, CRASY può mostrarlo qui '
                    'dentro e usarlo per raccontare com\'è finita questa '
                    'challenge.'
              : 'La foto resta tua. Mandandola, CRASY può mostrarla qui '
                    'dentro e usarla per raccontare com\'è finita questa '
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
    required this.source,
    required this.fotocameraAperta,
    required this.caption,
    required this.onRetake,
  });

  final PickedMedia media;
  final MediaKind kind;
  final ChallengeSource source;

  /// Vedi `_ParticipatePageState._fotocameraAperta`.
  final bool fotocameraAperta;

  /// La didascalia che si scrive **sulla** foto.
  final TextEditingController caption;

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
            //
            // **La didascalia e' in pausa.** La scritta curva attorno alla foto
            // e' rimasta a meta' strada — si appoggiava bene sull'anteprima e
            // male sulla foto grande, e rimpiccioliva l'immagine per farsi
            // spazio. Meglio spenta che sbagliata: il campo invisibile che
            // stava steso qui sopra e' stato tolto insieme a lei, o resterebbe
            // a mangiarsi i tocchi e ad aprire la tastiera per scrivere una
            // cosa che nessuno vedrebbe.
            child: media.isVideo
                ? _VideoReady(
                    percorso: media.filePath ?? '',
                    acceso: !fotocameraAperta,
                  )
                : Image.memory(media.bytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Rifare lo scatto prima di mandarlo si puo': il patto e' che non si
        // cambia **dopo** l'invio, quando la gara e' gia' cominciata.
        TextButton(
          onPressed: onRetake,
          // In una gara d'archivio non si rifa' niente: si va a prenderne
          // un'altra. "Scatta di nuovo" prometterebbe una fotocamera che qui
          // non si apre.
          child: Text(
            source.isArchive
                ? (kind.isVideo
                      ? 'Scegli un altro video'
                      : "Scegli un'altra foto")
                : (kind.isVideo ? 'Registra di nuovo' : 'Scatta di nuovo'),
          ),
        ),
      ],
    );
  }
}

/// La riga che spiega cosa si puo' mandare, e cosa no.
///
/// **Cambia con la gara, e deve.** Erano due frasi fisse che dicevano "niente
/// galleria" — vere fino a ieri, e da oggi false meta' delle volte. Una regola
/// scritta male e' peggio di una regola non scritta: la prima la si crede.
String _laRegola(Challenge challenge) {
  final video = challenge.mediaKind.isVideo;

  if (challenge.source.isArchive) {
    return video
        ? "Questa è una missione d'archivio: si prende un video che hai già, "
              "niente fotocamera. Un video solo a testa, e una volta mandato "
              "non si cambia."
        : "Questa è una missione d'archivio: si prende una foto che hai già, "
              "niente fotocamera. Una foto sola a testa, e una volta mandata "
              "non si cambia.";
  }

  return video
      ? 'Si registra sul momento, niente galleria. Al massimo '
            '${MediaKind.maxVideoDuration.inSeconds} secondi, un video solo a '
            'testa, e una volta mandato non si cambia.'
      : 'Si scatta sul momento, niente galleria. Una foto sola a testa, e una '
            'volta mandata non si cambia.';
}

/// Il video appena registrato, da rivedere prima di mandarlo.
///
/// **Prima non si vedeva.** C'era un riquadro grigio con scritto "VIDEO
/// PRONTO", e la ragione messa a verbale era che riprodurre un file locale
/// vuole strade diverse su telefono e su web e non valeva la complicazione per
/// i due secondi che sta li'.
///
/// Era sbagliata, e per un motivo che non c'entra con i due secondi: **una
/// partecipazione si manda una volta sola e non si cambia**. Mandare senza aver
/// guardato vuol dire scoprire dopo di aver consegnato tre secondi di soffitto,
/// o il video interrotto un istante prima della cosa per cui l'avevi girato. La
/// foto la si e' sempre vista; il video no, ed era l'unica cosa che si
/// consegnava alla cieca.
///
/// Parte da solo e va in ciclo, con l'audio: si sta controllando il proprio
/// video, e meta' di quello che c'e' da controllare si sente invece di vedersi.
/// Un tocco lo ferma.
///
/// Sul web resta il riquadro di prima: li' il file non ha un percorso da
/// aprire — il browser consegna dei byte — e non c'e' niente da riprodurre.
class _VideoReady extends StatefulWidget {
  const _VideoReady({required this.percorso, required this.acceso});

  final String percorso;

  /// **Falso mentre la fotocamera e' aperta, e conta.**
  ///
  /// Un lettore video acceso tiene occupato l'audio del telefono. La
  /// fotocamera, per registrare, ha bisogno del microfono: lo trova gia' preso
  /// e non parte — e' il motivo per cui "registra di nuovo" non funzionava.
  /// Spento, il lettore lascia andare tutto e la fotocamera riparte.
  final bool acceso;

  @override
  State<_VideoReady> createState() => _VideoReadyState();
}

class _VideoReadyState extends State<_VideoReady> {
  VideoPlayerController? _lettore;
  var _pronto = false;

  @override
  void initState() {
    super.initState();

    if (widget.acceso) {
      unawaited(_apri());
    }
  }

  @override
  void didUpdateWidget(_VideoReady vecchio) {
    super.didUpdateWidget(vecchio);

    if (!widget.acceso && _lettore != null) {
      // Si molla tutto: il lettore, e con lui l'audio del telefono.
      _lettore?.dispose();
      _lettore = null;
      _pronto = false;
    } else if (widget.acceso && _lettore == null) {
      unawaited(_apri());
    }
  }

  @override
  void dispose() {
    _lettore?.dispose();
    super.dispose();
  }

  Future<void> _apri() async {
    final lettore = lettoreDalDisco(widget.percorso);

    if (lettore == null) {
      return;
    }

    try {
      await lettore.initialize();
      await lettore.setLooping(true);
      await lettore.play();
    } on Object {
      // **Un'anteprima che non parte non deve fermare l'invio.** Il file c'e'
      // ed e' buono: se il lettore non lo apre — un formato che questo telefono
      // non decodifica, un permesso — si torna al riquadro di prima e la foto
      // parte lo stesso.
      await lettore.dispose();

      return;
    }

    if (!mounted) {
      await lettore.dispose();

      return;
    }

    setState(() {
      _lettore = lettore;
      _pronto = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lettore = _lettore;

    if (!_pronto || lettore == null) {
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
              style: context.texts.labelSmall?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() {
        lettore.value.isPlaying ? lettore.pause() : lettore.play();
      }),
      child: ColoredBox(
        color: palette.surfaceMuted,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Come nel resto dell'app: riempie il riquadro invece di lasciare
            // due bande nere dove le proporzioni non combaciano.
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: lettore.value.size.width,
                height: lettore.value.size.height,
                child: VideoPlayer(lettore),
              ),
            ),
            if (!lettore.value.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
