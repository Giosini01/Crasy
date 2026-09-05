import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/countdown_text.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/media_gestures.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/challenges/presentation/widgets/fire_tap.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Una challenge nella home.
///
/// La gerarchia e' tutto qui dentro, e l'ordine non e' casuale: **premio,
/// titolo, consegna, tempo, comando** — poi la vetrina. E' l'ordine in cui uno
/// decide se la cosa lo riguarda: quanto si vince, cosa bisogna fare, quanto
/// tempo resta, come si entra. Solo dopo aver deciso viene voglia di vedere
/// cosa hanno combinato gli altri.
///
/// Non e' una scheda: non c'e' un riquadro, non c'e' un'ombra, non c'e' un
/// fondo diverso. E' un blocco di pagina, e a separarlo dal successivo e' solo
/// dello spazio bianco.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({
    required this.challenge,
    required this.onOpen,
    required this.onParticipate,
    super.key,
  });

  final Challenge challenge;
  final VoidCallback onOpen;
  final VoidCallback onParticipate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final myEntry = ref.watch(myEntryForChallengeProvider(challenge.id));
    // Il valore, non l'attesa: finche' la foto in vetrina non e' arrivata la
    // scheda si mostra senza — come faceva prima — e la foto compare quando
    // c'e'.
    final leader = ref
        .watch(challengeTopEntryProvider(challenge.id))
        .valueOrNull;
    final isMine =
        challenge.createdByUserId.isNotEmpty &&
        challenge.createdByUserId == ref.watch(currentUserIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onOpen,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Il premio in rosso, ed e' la cosa piu' grande della
                  // schermata. Se non lo fosse, questa sarebbe un'app di foto
                  // qualunque.
                  Expanded(
                    child: Text(
                      challenge.prizeLabel,
                      style: texts.displayLarge?.copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      challenge.scopeLabel,
                      style: texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(challenge.title.toUpperCase(), style: texts.displayMedium),
              if (challenge.brief.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                // La consegna, non un riassunto: due righe bastano a dire cosa
                // bisogna fare, e chi ne vuole di piu' apre la challenge.
                Text(
                  challenge.brief,
                  style: texts.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              ChallengeMetaRow(challenge: challenge),
              if (challenge.hasCreator) ...[
                const SizedBox(height: AppSpacing.xs),
                ChallengeAuthor(challenge: challenge),
              ],
            ],
          ),
        ),
        if (leader != null) ...[
          const SizedBox(height: AppSpacing.lg),
          ChallengeShowcase(
            entry: leader,
            challenge: challenge,
            onOpen: onOpen,
          ),
        ],
        // Il comando chiude il blocco, sempre. Dopo aver visto cosa sta
        // vincendo si sa cosa bisogna battere, ed e' quello il momento in cui
        // uno decide se partecipare — non prima.
        const SizedBox(height: AppSpacing.md),
        if (isMine)
          const OwnChallengeNote()
        else if (myEntry != null)
          const AlreadyJoinedNote()
        // **Al completo il bottone non c'e' piu'.** Lasciarlo e farlo rifiutare
        // dopo lo scatto vorrebbe dire far spendere l'unico scatto per sentirsi
        // dire di no.
        else if (challenge.isFull)
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: palette.textFaint,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Posti finiti. Questa gara è al completo.',
                  style: texts.labelMedium?.copyWith(color: palette.textFaint),
                ),
              ),
            ],
          )
        else
          CrasyButton(label: 'Partecipa', onPressed: onParticipate),
      ],
    );
  }
}

/// La vetrina: la foto in testa alla challenge.
///
/// Una sola, la piu' votata, grande. E' la risposta alla domanda che uno si fa
/// leggendo la consegna — *cosa ci si e' inventato la gente?* — e insieme il
/// metro con cui misurarsi: per vincere bisogna fare meglio di questa.
///
/// Toccandola si entra nella challenge, dove ci sono tutte le altre. Il numero
/// di fiamme sta sopra la foto e non sotto: e' l'unica cosa che va letta
/// insieme all'immagine, non dopo.
class ChallengeShowcase extends StatelessWidget {
  const ChallengeShowcase({
    required this.entry,
    required this.challenge,
    required this.onOpen,
    super.key,
  });

  final ChallengeEntry entry;

  /// La gara a cui appartiene: serve a sapere **se e' ancora in corso**, e a
  /// gara in corso qui non si dice chi sta vincendo.
  final Challenge challenge;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return MediaTap(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **A gara aperta qui non c'e' nessuna classifica.**
          //
          // Diceva "IN TESTA" con accanto il numero delle fiamme, e con i voti
          // nascosti quella riga sarebbe la classifica scritta in un altro modo:
          // basta guardare la copertina di ogni gara per sapere chi sta
          // vincendo. Al suo posto c'e' **l'ultima arrivata** e quanti sono in
          // gara — due informazioni che invogliano a entrare senza dire a
          // nessuno come sta andando.
          //
          // Finita la gara si torna a dire tutto: chi ha vinto, con quante.
          Row(
            children: [
              Text(
                challenge.isOver ? 'HA VINTO' : 'ULTIMA ARRIVATA',
                style: texts.labelSmall?.copyWith(
                  color: challenge.isOver ? palette.accent : palette.textFaint,
                ),
              ),
              const Spacer(),
              if (challenge.isOver) ...[
                Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: palette.accent,
                ),
                const SizedBox(width: 2),
                Text(
                  '${entry.votes}',
                  style: texts.labelMedium?.copyWith(color: palette.accent),
                ),
              ] else
                Text(
                  challenge.crowdLabel,
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                ),
            ],
          ),
          // **Quattro punti sopra e sotto, non otto.** Il conto delle fiamme
          // e il nome di chi sta vincendo appartengono a quella foto: staccati
          // di otto punti diventavano due righe che galleggiano, una troppo in
          // alto e una troppo in basso. Vicini si leggono come le due
          // didascalie della stessa immagine.
          const SizedBox(height: AppSpacing.xxs),
          // **Sulla foto vale la fiamma, come ovunque.** Il resto della scheda
          // apre la challenge; qui sopra no: un tocco apre lo stesso, ma due
          // accendono la fiamma. Prima questo pezzo non ascoltava il doppio
          // tocco affatto, e due tocchi rapidi sulla foto in testa aprivano la
          // gara due volte di fila.
          FireTap(
            entry: entry,
            onTap: onOpen,
            // **Nove decimi, e ci restiamo.**
            //
            // Si e' provato a schiacciarla a sedici decimi per far entrare due
            // gare nella stessa schermata. Non funziona: il resto della scheda
            // — premio, titolo, consegna, comando — pesa da solo mezzo
            // telefono, quindi la seconda gara non entrava lo stesso, e in
            // cambio la foto diventava una striscia. **La foto e' il
            // contenuto**, ed e' l'ultima cosa da sacrificare per far entrare
            // altra interfaccia.
            child: MediaFrame(
              // A tutta larghezza: l'originale. Vedi `EntryTile`.
              url: entry.mediaUrl,
              video: entry.isVideo,
              aspectRatio: 0.9,
              caption: entry.authorName,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '@${entry.authorName}',
                  style: texts.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'VEDI TUTTE',
                style: texts.labelSmall?.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: palette.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chi ha lanciato la challenge.
///
/// Con dei soldi in palio, **chi li mette e' un'informazione**, non un dettaglio
/// di cortesia: cambia la fiducia con cui uno decide di partecipare. Le
/// challenge di CRASY portano il nome di CRASY, quelle di una persona il suo.
///
/// C'e' solo l'iniziale e non la foto: la riga sta dentro un elenco lungo, e
/// leggere una foto profilo per ogni challenge sarebbe un costo pagato ogni
/// volta per un dettaglio che non cambia la decisione di partecipare.
///
/// Il nome si tocca e porta al profilo di chi ha lanciato la challenge — chi
/// mette in palio dei soldi e' proprio la persona su cui uno vuole poter dare
/// un'occhiata prima di uscire di casa a fare una cosa folle.
class ChallengeAuthor extends StatelessWidget {
  const ChallengeAuthor({required this.challenge, super.key});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final official = challenge.createdByUserId.isEmpty;

    return GestureDetector(
      onTap: official
          ? null
          : () => context.push(
              AppRoutes.userProfileOf(challenge.createdByUserId),
            ),
      behavior: HitTestBehavior.opaque,
      child: _row(context, palette, texts, official: official),
    );
  }

  Widget _row(
    BuildContext context,
    AppPalette palette,
    TextTheme texts, {
    required bool official,
  }) {
    return Row(
      children: [
        // **CRASY ha una faccia come tutti gli altri.**
        //
        // Le sfide del giorno sono sue, e una gara senza volto sembra arrivata
        // da un ufficio. Con la sua fotografia — l'icona dell'app — la sfida
        // del giorno diventa una cosa che qualcuno ti ha chiesto di fare, che
        // e' la stessa promessa delle altre gare.
        if (challenge.byCrasy)
          FriendAvatar(
            userId: challenge.createdByUserId,
            username: challenge.createdByUsername,
            size: 20,
          )
        else
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: official ? palette.accentTint : palette.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: official
                ? Icon(
                    Icons.local_fire_department,
                    size: 12,
                    color: palette.accent,
                  )
                : Text(
                    // Il nome puo' arrivare vuoto da una challenge scritta male:
                    // `substring` su una stringa vuota fa saltare l'intera lista.
                    challenge.createdByUsername.isEmpty
                        ? '?'
                        : challenge.createdByUsername
                              .substring(0, 1)
                              .toUpperCase(),
                    style: texts.labelSmall?.copyWith(
                      color: palette.textSecondary,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'Lanciata da @${challenge.createdByUsername}',
            style: texts.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Cosa prende il posto del comando sulle challenge che hai lanciato tu.
///
/// Chi mette il premio non corre per vincerlo. Detto qui invece che con un
/// bottone che poi rifiuta: il limite si spiega prima, non dopo lo scatto.
class OwnChallengeNote extends StatelessWidget {
  const OwnChallengeNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(
          Icons.workspace_premium_outlined,
          size: 16,
          color: palette.textFaint,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'L\'hai lanciata tu — il premio lo metti tu',
            style: context.texts.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Cosa prende il posto del comando quando hai gia' mandato la tua foto.
///
/// Non un bottone spento: un bottone spento invita comunque a premerlo e poi
/// non fa niente. Una riga di testo dice la stessa cosa e non promette nulla.
class AlreadyJoinedNote extends StatelessWidget {
  const AlreadyJoinedNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(Icons.check_rounded, size: 16, color: palette.accent),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Hai già partecipato',
          style: context.texts.labelLarge?.copyWith(color: palette.accent),
        ),
      ],
    );
  }
}

/// La riga di servizio: quanto manca, quanti stanno giocando.
///
/// Un punto medio a separarle e nient'altro. Due icone qui — un orologio e una
/// sagoma — sarebbero due disegni per dire quello che le parole dicono gia'.
class ChallengeMetaRow extends StatelessWidget {
  const ChallengeMetaRow({required this.challenge, super.key});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.texts.labelMedium;
    final ended = challenge.hasEndedAt(DateTime.now());

    return Row(
      children: [
        if (ended)
          Text('chiusa', style: style)
        else
          CountdownText(
            target: challenge.endsAt,
            style: style,
            urgentColor: palette.accent,
          ),
        Text('  ·  ', style: style),
        Text(
          '${challenge.participantsCount} '
          '${challenge.participantsCount == 1 ? 'partecipante' : 'partecipanti'}',
          style: style,
        ),
        // **I posti che restano, in rosso.**
        //
        // E' l'unica cosa di questa riga che cambia il comportamento di chi
        // legge: "restano tre posti" e' il motivo piu' forte che esista per
        // partecipare adesso invece che stasera. Al completo diventa
        // un'informazione altrettanto utile — smetti di pensarci.
        if (!ended && challenge.spotsLeft != null) ...[
          Text('  ·  ', style: style),
          Text(
            challenge.isFull ? 'al completo' : '${challenge.spotsLeft} liberi',
            style: style?.copyWith(color: palette.accent),
          ),
        ],
      ],
    );
  }
}
