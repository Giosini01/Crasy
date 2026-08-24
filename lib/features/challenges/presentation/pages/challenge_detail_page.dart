import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/controllers/challenge_closer.dart';
import 'package:crasy/features/challenges/presentation/controllers/vote_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:crasy/features/challenges/presentation/widgets/entry_tile.dart';
import 'package:crasy/features/challenges/presentation/widgets/fire_tap.dart';
import 'package:crasy/features/challenges/presentation/widgets/fullscreen_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// La pagina di una challenge: cosa c'e' in palio, cosa bisogna fare, chi ha
/// gia' mandato qualcosa.
///
/// Il comando per partecipare sta **incollato in fondo allo schermo** e non in
/// coda alla pagina. Le regole e le partecipazioni sono lunghe da scorrere, e
/// un bottone che si raggiunge solo arrivando in fondo e' un bottone che meta'
/// delle persone non vede mai.
class ChallengeDetailPage extends ConsumerWidget {
  const ChallengeDetailPage({required this.challengeId, super.key});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeState = ref.watch(challengeProvider(challengeId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _leave(context)),
        title: const Text('Challenge'),
      ),
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

            return _Body(challenge: challenge);
          },
        ),
      ),
      bottomNavigationBar: challengeState.valueOrNull == null
          ? null
          : _BottomAction(challenge: challengeState.value!),
    );
  }

  /// Chi arriva qui da una notifica o da un link non ha una pagina precedente:
  /// senza questo controllo il tasto indietro non farebbe niente e lascerebbe
  /// la persona bloccata sul dettaglio.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.challenges);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final entries = ref.watch(challengeEntriesProvider(challenge.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                challenge.prizeLabel,
                style: texts.displayLarge?.copyWith(color: palette.accent),
              ),
            ),
            Text(
              challenge.scopeLabel,
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(challenge.title.toUpperCase(), style: texts.displaySmall),
        // Qui dentro **non** c'e' la foto in testa, e fuori si': nella home
        // serve a far capire di che gara si tratta, ma dopo aver aperto la
        // challenge sarebbe la stessa immagine due volte di fila, e per giunta
        // sopra la griglia dove quella foto compare di nuovo. Chi entra qui
        // vuole scorrere e vederle tutte.
        const SizedBox(height: AppSpacing.lg),
        Text(challenge.brief, style: texts.bodyLarge),
        if (challenge.hasCreator) ...[
          const SizedBox(height: AppSpacing.md),
          ChallengeAuthor(challenge: challenge),
        ],
        const SizedBox(height: AppSpacing.lg),
        _TimeBlock(challenge: challenge),
        if (challenge.rules.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'REGOLE',
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final rule in challenge.rules)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('—  ', style: texts.bodyMedium),
                  Expanded(child: Text(rule, style: texts.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          challenge.hasEndedAt(DateTime.now())
              ? 'IL VINCITORE'
              : 'PARTECIPAZIONI',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.md),
        entries.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Text(
            'Non riusciamo a caricare le partecipazioni.',
            style: texts.bodyMedium,
          ),
          data: (items) => _Entries(challenge: challenge, entries: items),
        ),
      ],
    );
  }
}

/// Il tempo e i partecipanti, grandi.
///
/// Nella home la stessa informazione sta su una riga di servizio; qui e' una
/// delle cose per cui uno ha aperto la pagina, e prende il corpo che merita.
class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final ended = challenge.hasEndedAt(DateTime.now());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ended ? 'CONCLUSA' : 'TEMPO RIMASTO',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.xxs),
              if (ended)
                Text('—', style: texts.headlineSmall)
              else
                CountdownText(
                  target: challenge.endsAt,
                  style: texts.headlineSmall,
                  urgentColor: palette.accent,
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PARTECIPANTI',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${challenge.participantsCount}',
                style: texts.headlineSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Le partecipazioni, e la foto che qualcuno e' venuto a vedere.
///
/// Se l'indirizzo porta con se' `?foto=`, quella foto si apre grande da sola,
/// una volta sola. E' il link che gira fuori da CRASY: chi lo riceve deve
/// trovarsi davanti **la cosa di cui gli hanno parlato**, non una pagina in cui
/// cercarla. La gara resta sotto, a un tocco di distanza.
class _Entries extends ConsumerStatefulWidget {
  const _Entries({required this.challenge, required this.entries});

  final Challenge challenge;
  final List<ChallengeEntry> entries;

  @override
  ConsumerState<_Entries> createState() => _EntriesState();
}

class _EntriesState extends ConsumerState<_Entries> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openSharedEntry();
    _closeIfOver();
  }

  /// Chiude la gara se e' scaduta e nessuno l'ha ancora proclamata.
  ///
  /// Lo dovrebbe fare il server ogni cinque minuti, e il codice c'e' gia': gli
  /// manca il piano a pagamento. Finche' non c'e', a chiudere e' il primo che
  /// apre la gara dopo la scadenza — vedi `ChallengeCloser`, che spiega perche'
  /// questa strada si spegne da sola il giorno in cui girano dei soldi veri.
  void _closeIfOver() {
    final challenge = widget.challenge;
    final entries = widget.entries;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Qui l'elenco arriva dal ramo `data` dello stream, quindi e' per
        // definizione caricato.
        ref
            .read(challengeCloserProvider)
            .closeIfNeeded(challenge, entries, entriesLoaded: true);
      }
    });
  }

  /// Apre la foto indicata dall'indirizzo.
  ///
  /// Una volta sola, e il segno di averlo fatto e' un campo di stato: le
  /// partecipazioni arrivano da uno stream e questo widget si ricostruisce a
  /// ogni fiamma che qualcuno accende. Senza il segno, la foto si riaprirebbe
  /// da sola sopra a quella che si sta guardando.
  void _openSharedEntry() {
    if (_opened) {
      return;
    }

    final wanted = GoRouterState.of(context).uri.queryParameters['foto'];

    if (wanted == null || wanted.isEmpty || widget.entries.isEmpty) {
      return;
    }

    final entry = widget.entries.where((item) => item.id == wanted).firstOrNull;

    if (entry == null) {
      return;
    }

    _opened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FullscreenMedia.open(context, entries: widget.entries, entry: entry);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final entries = widget.entries;

    if (entries.isEmpty) {
      return Text(
        'Ancora nessuno. Puoi essere il primo.',
        style: context.texts.bodyMedium,
      );
    }

    // A challenge chiusa vince una foto sola, e va vista grande: mostrarla
    // nella stessa griglia da due colonne delle altre significherebbe non
    // proclamare nessuno.
    final winnerId = challenge.winnerEntryId;

    if (winnerId != null) {
      final winner = entries.where((entry) => entry.id == winnerId).firstOrNull;

      if (winner != null) {
        return EntryTile(entry: winner, showChallenge: false);
      }
    }

    final me = ref.watch(currentUserIdProvider);
    final aspetta = challenge.waitsForChoiceAt(DateTime.now());
    final scelgoIo = aspetta && me != null && me == challenge.createdByUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aspetta) _ChoiceBanner(challenge: challenge, mine: scelgoIo),
        // Le fiamme rimaste stanno **sopra le foto**, non sotto: si guardano
        // prima di cominciare a spenderle, non dopo averle finite.
        if (!challenge.hasEndedAt(DateTime.now())) ...[
          _FireBudget(challengeId: challenge.id),
          const SizedBox(height: AppSpacing.md),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.lg,
            // Il quadrato della foto piu' la riga sotto. Fissato invece che
            // calcolato da un rapporto, cosi' la riga non si schiaccia quando la
            // colonna si stringe — e piu' alto quando sotto c'e' anche il
            // comando per assegnare il premio.
            mainAxisExtent: scelgoIo ? 258 : 210,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) => _EntryGridTile(
            entry: entries[index],
            entries: entries,
            // Il comando per assegnare il premio compare **solo a chi la gara
            // l'ha lanciata**, e solo mentre il tempo per scegliere corre.
            choosable: scelgoIo ? challenge : null,
          ),
        ),
      ],
    );
  }
}

class _EntryGridTile extends ConsumerWidget {
  const _EntryGridTile({
    required this.entry,
    required this.entries,
    this.choosable,
  });

  /// La gara, quando **io posso assegnarne il premio**. Nulla in tutti gli
  /// altri casi, che sono la stragrande maggioranza.
  final Challenge? choosable;

  final ChallengeEntry entry;

  /// Tutte le partecipazioni della gara, per poter scorrere da questa alle
  /// altre una volta aperta a schermo intero.
  final List<ChallengeEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FireTap(
          entry: entry,
          // Un tocco solo apre la foto grande; il doppio tocco resta la
          // fiamma. Nel quadrato di due dita della griglia non si vede niente:
          // e' un indice, non il contenuto.
          onTap: () =>
              FullscreenMedia.open(context, entries: entries, entry: entry),
          child: MediaFrame(
            url: entry.mediaUrl,
            video: entry.isVideo,
            aspectRatio: 1,
            caption: entry.authorName,
            mine: entry.userId == ref.watch(currentUserIdProvider),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Expanded(
              // Anche qui il nome apre il profilo: chi vede una foto che gli
              // piace deve poter arrivare a chi l'ha fatta da dove si trova,
              // senza tornare indietro a cercarla altrove.
              child: GestureDetector(
                onTap: () =>
                    context.push(AppRoutes.userProfileOf(entry.userId)),
                child: Text(
                  '@${entry.authorName}',
                  style: context.texts.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            VoteButton(entry: entry),
          ],
        ),
        if (choosable != null)
          _ChooseButton(challenge: choosable!, entry: entry),
      ],
    );
  }
}

/// Il comando in fondo, sempre visibile.
class _BottomAction extends ConsumerWidget {
  const _BottomAction({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final ended = challenge.hasEndedAt(DateTime.now());
    final myEntry = ref.watch(myEntryForChallengeProvider(challenge.id));
    final isMine = ref.watch(isMyChallengeProvider(challenge.id));

    return Container(
      color: palette.background,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      child: switch ((ended, isMine, myEntry)) {
        (true, _, _) => ChallengeMetaRow(challenge: challenge),
        (false, true, _) => const OwnChallengeNote(),
        (false, false, final entry?) => Row(
          children: [
            const AlreadyJoinedNote(),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: palette.accent,
                ),
                const SizedBox(width: 4),
                Text('${entry.votes}', style: context.texts.titleMedium),
              ],
            ),
          ],
        ),
        (false, false, null) => CrasyButton(
          label: 'Partecipa',
          onPressed: () => context.push(AppRoutes.participateOf(challenge.id)),
        ),
      },
    );
  }
}

/// Chi ha lanciato la gara sceglie, e questa e' la riga che glielo dice.
///
/// **Il verdetto non e' del conteggio, e' suo.** Le fiamme restano sotto ogni
/// foto — servono a capire il polso di chi guarda, e a decidere in automatico
/// se lui non decide — ma chi ha messo i soldi sta comprando un'opera, e la
/// piu' votata non e' sempre quella che aveva chiesto.
///
/// Agli altri la stessa riga dice due cose: che si sta aspettando una persona
/// precisa, e **entro quando**. Una gara finita che non dice chi ha vinto ne'
/// perche' e' il modo piu' rapido di far pensare che i soldi non arriveranno.
class _ChoiceBanner extends ConsumerWidget {
  const _ChoiceBanner({required this.challenge, required this.mine});

  final Challenge challenge;

  /// Vero se a dover scegliere sono io.
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final left = challenge.decisionDeadline.difference(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mine ? 'SCEGLI CHI HA VINTO' : 'IN ATTESA DELLA SCELTA',
            style: texts.labelSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mine
                ? 'La gara e\' finita: il premio lo assegni tu. Se non scegli '
                      'entro ${AppDateUtils.formatTimeLeft(left)}, va da solo '
                      'a chi ha piu\' fiamme.'
                : 'Decide @${challenge.createdByUsername}, che ha messo il '
                      'premio. Se non lo fa entro '
                      '${AppDateUtils.formatTimeLeft(left)}, vince chi ha piu\' '
                      'fiamme.',
            style: texts.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Il comando che assegna il premio, sotto una foto.
///
/// Chiede conferma, e non per abitudine: **questo tocco sposta dei soldi veri e
/// non si disfa**. Una gara proclamata non si riapre, ne' dall'app ne' dalle
/// regole del database — e' il patto con chi ha partecipato.
class _ChooseButton extends ConsumerWidget {
  const _ChooseButton({required this.challenge, required this.entry});

  final Challenge challenge;
  final ChallengeEntry entry;

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vince @${entry.authorName}?'),
        content: Text(
          '${challenge.prizeLabel} vanno a lei o a lui, e non si torna '
          'indietro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'ASSEGNA',
              style: TextStyle(color: context.palette.accent),
            ),
          ),
        ],
      ),
    );

    if (conferma != true) {
      return;
    }

    await ref
        .read(challengeRepositoryProvider)
        .proclaimWinner(
          challengeId: challenge.id,
          winnerEntryId: entry.id,
          winnerUserId: entry.userId,
          chosenByCreator: true,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: SecondaryButton(
        label: 'Scegli questa',
        accent: true,
        onPressed: () => _choose(context, ref),
      ),
    );
  }
}

/// Le fiamme che restano in questa gara, disegnate.
///
/// **Tre segni, non un numero.** "Ti restano 2 fiamme" si legge; tre fiamme di
/// cui una spenta si *vede*, e chi guarda capisce in un colpo d'occhio due cose
/// insieme: quante ne ha date e quante gliene restano. Su una schermata che si
/// scorre col pollice vale piu' della frase.
///
/// Sparisce a gara finita: li' non c'e' piu' niente da spendere, e un contatore
/// pieno sotto una gara chiusa e' una promessa che non si puo' mantenere.
class _FireBudget extends ConsumerWidget {
  const _FireBudget({required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final left = ref.watch(firesLeftProvider(challengeId));
    final finite = left == 0;

    return Row(
      children: [
        for (var i = 0; i < Challenge.firesPerChallenge; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              i < left
                  ? Icons.local_fire_department
                  : Icons.local_fire_department_outlined,
              size: 16,
              color: i < left ? palette.accent : palette.textFaint,
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          finite ? 'FINITE QUI' : 'TE NE RESTANO $left',
          style: texts.labelSmall?.copyWith(
            color: finite ? palette.textFaint : palette.accent,
          ),
        ),
      ],
    );
  }
}
