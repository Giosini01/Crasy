import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:flutter/material.dart';

/// Da che parte del tavolo si guarda un trofeo.
///
/// La stessa gara produce **due figurine diverse**, e non e' un dettaglio: chi
/// ha vinto racconta una cosa sua — *questa foto l'ho fatta io e mi ha pagato* —
/// chi l'ha commissionata ne racconta un'altra, che e' *questa cosa l'ho fatta
/// fare io*. Sono due orgogli diversi, e schiacciarli sulla stessa scritta
/// vorrebbe dire non dire niente a nessuno dei due.
enum TrophyKind {
  /// L'ho vinta.
  won('VINTA', 'HAI VINTO'),

  /// L'ho fatta fare.
  commissioned('COMANDATA', 'HAI FATTO FARE');

  const TrophyKind(this.label, this.headline);

  /// La parola sulla figurina.
  final String label;

  /// La riga in cima al dettaglio.
  final String headline;

  bool get isWon => this == TrophyKind.won;
}

/// Una figurina: la foto che ha vinto, incorniciata, con sopra il suo valore.
///
/// **Non e' una riga di elenco, ed e' voluto.** Una vittoria raccontata come
/// "CHALLENGE X — 45 euro" e' una voce di estratto conto. Qui invece si vede
/// per prima cosa la foto — la cosa che uno ha fatto davvero — e il numero le
/// sta sopra come il valore stampato su una carta da collezione. E' la stessa
/// differenza che c'e' fra un elenco di partite giocate e un album.
///
/// La cornice e' rossa in tutti e due i casi. In CRASY il rosso vuol dire
/// premio, fiamma, cosa attiva: un trofeo e' tutte e tre.
class TrophyCard extends StatelessWidget {
  const TrophyCard({required this.challenge, required this.kind, super.key});

  final Challenge challenge;
  final TrophyKind kind;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: () => showTrophy(context, challenge: challenge, kind: kind),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaFrame(
            url: challenge.winnerMediaUrl,
            video: challenge.winnerMediaKind.isVideo,
            aspectRatio: 1,
            radius: AppRadius.xs,
            // La cornice rossa che nel resto dell'app dice "questa e' tua" qui
            // dice "questa e' tua **per sempre**". E' lo stesso segno, ed e' la
            // ragione per cui non ne serve uno nuovo.
            mine: true,
          ),
          // La striscia scura sotto **non e' decorazione**: senza, il numero
          // finisce sopra una foto qualunque, e su una foto chiara sparisce. Il
          // valore di un trofeo e' l'unica cosa che deve leggersi sempre.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.xs),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kind.label,
                      style: context.texts.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 8,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      // **Chi vince legge quello che ha incassato**, non quello
                      // che era scritto in vetrina: il premio meno la
                      // percentuale di CRASY. Chi ha commissionato legge invece
                      // quanto ha messo, perche' e' quello che ha speso.
                      AppMoney.format(
                        kind.isWon
                            ? challenge.payoutCents
                            : challenge.prizeCents,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleMedium?.copyWith(
                        color: palette.accent,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il retro della figurina: tutto quello che c'era dietro quella foto.
///
/// Si apre toccando il trofeo, e serve a una cosa sola: **rimettere la foto nel
/// suo contesto**. Sei mesi dopo, di una gara non ci si ricorda niente — cosa
/// chiedeva, quanto era in palio, chi l'aveva lanciata, quante fiamme aveva
/// preso. Senza queste righe il trofeo e' una foto qualunque nel proprio
/// telefono; con queste righe e' una cosa che e' successa.
Future<void> showTrophy(
  BuildContext context, {
  required Challenge challenge,
  required TrophyKind kind,
}) {
  return ModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: kind.headline,
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: _TrophyDetails(challenge: challenge, kind: kind),
    ),
  );
}

class _TrophyDetails extends StatelessWidget {
  const _TrophyDetails({required this.challenge, required this.kind});

  final Challenge challenge;
  final TrophyKind kind;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MediaFrame(
          url: challenge.winnerMediaUrl,
          video: challenge.winnerMediaKind.isVideo,
          aspectRatio: 1,
          mine: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(challenge.title.toUpperCase(), style: texts.headlineSmall),
        if (challenge.brief.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            challenge.brief,
            style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _Line(
          label: kind.isWon ? 'Hai incassato' : 'Hai messo in palio',
          value: AppMoney.format(
            kind.isWon ? challenge.payoutCents : challenge.prizeCents,
          ),
          accent: true,
        ),
        // Chi ha vinto sa gia' chi e'. Chi ha commissionato spesso no: e' la
        // riga che trasforma "una foto" in "la foto di quella persona".
        if (!kind.isWon && challenge.winnerUsername.isNotEmpty)
          _Line(label: 'L\'ha fatta', value: '@${challenge.winnerUsername}'),
        if (kind.isWon && challenge.hasCreator)
          _Line(
            label: 'L\'aveva chiesta',
            value: '@${challenge.createdByUsername}',
          ),
        _Line(label: 'Fiamme', value: '${challenge.winnerVotes}'),
        if (challenge.participantsCount > 0)
          _Line(
            label: 'Hanno partecipato',
            value: '${challenge.participantsCount}',
          ),
        _Line(
          label: 'Finita',
          value: AppDateUtils.formatItalianDate(challenge.endsAt),
        ),
        // **Assegnata o scaduta non e' la stessa cosa**, e chi ha in mano il
        // trofeo ha diritto di saperlo: uno l'ha scelto una persona, l'altro
        // l'ha deciso il tempo che passava.
        _Line(
          label: 'Il premio',
          value: challenge.chosenByCreator
              ? 'scelto da chi l\'ha lanciata'
              : 'andato a chi aveva piu\' fiamme',
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// Una riga del retro: l'etichetta a sinistra, il valore a destra.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: accent
                  ? context.texts.titleMedium?.copyWith(color: palette.accent)
                  : context.texts.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// La bacheca: le figurine tre per riga, come le foto.
///
/// Stessa griglia delle partecipazioni, di proposito. Un trofeo e' pur sempre
/// una foto, e dargli un'impaginazione tutta sua vorrebbe dire che passando da
/// una sezione all'altra del profilo cambia il ritmo della pagina — la cosa che
/// fa sembrare un'app cucita insieme da pezzi diversi.
class TrophyGrid extends StatelessWidget {
  const TrophyGrid({required this.challenges, required this.kind, super.key});

  final List<Challenge> challenges;
  final TrophyKind kind;

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
      itemCount: challenges.length,
      itemBuilder: (context, index) =>
          TrophyCard(challenge: challenges[index], kind: kind),
    );
  }
}
