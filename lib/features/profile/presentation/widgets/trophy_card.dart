import 'dart:math' as math;

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
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

/// **La figurina e' un oggetto, non un riquadro dell'interfaccia.**
///
/// Qui dentro ci sono un bordo di due colori, un riflesso in diagonale e
/// un'ombra — cioe' tre cose che in tutto il resto di CRASY sono vietate, e per
/// una ragione buona: le schermate si separano con lo spazio vuoto, e ogni
/// ombra aggiunta e' un pezzo di un'altra app.
///
/// Qui la regola si rompe apposta, ed e' l'unico posto in cui succede. Una
/// figurina non e' una scheda: e' una **cosa che si possiede**, e le cose che si
/// possiedono hanno uno spessore, riflettono la luce e hanno un davanti e un
/// dietro. Un rettangolo piatto con dentro una foto racconta un archivio; questo
/// racconta un premio. La differenza e' tutto il motivo per cui la sezione
/// esiste.
///
/// Il bordo e' rosso CRASY perche' e' il colore dei premi, e il riflesso e'
/// tenuto basso: deve leggersi come plastica, non come uno specchio.
class TrophyFront extends StatelessWidget {
  const TrophyFront({required this.challenge, required this.kind, super.key});

  final Challenge challenge;
  final TrophyKind kind;

  /// Le proporzioni di una figurina vera, non un quadrato.
  ///
  /// Sono quelle delle carte da collezione — piu' alta che larga — e non e'
  /// vezzo: un quadrato e' il formato di una griglia di foto, e una griglia di
  /// foto e' esattamente cio' che questa sezione **non** deve sembrare.
  static const double ratio = 0.72;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _Laminated(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaFrame(
            url: challenge.winnerMediaUrl,
            video: challenge.winnerMediaKind.isVideo,
            aspectRatio: ratio,
            radius: AppRadius.sm,
          ),
          // La fascia scura sotto **non e' decorazione**: senza, il valore
          // finisce sopra una foto qualunque, e su una foto chiara sparisce. Il
          // numero di un trofeo e' l'unica cosa che deve leggersi sempre.
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
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.sm),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kind.label,
                      style: context.texts.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 8,
                        letterSpacing: 1.4,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        // **Chi vince legge quello che ha incassato**, non il
                        // numero della vetrina: il premio meno la percentuale
                        // di CRASY. Chi ha commissionato legge quanto ha messo,
                        // perche' e' quello che ha speso.
                        AppMoney.format(
                          kind.isWon
                              ? challenge.payoutCents
                              : challenge.prizeCents,
                        ),
                        style: context.texts.headlineSmall?.copyWith(
                          color: palette.accent,
                          height: 1,
                        ),
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

/// Il dietro: il marchio in bianco su rosso, e cos'era quella gara.
///
/// **Una figurina senza retro e' una foto incorniciata.** Il dietro e' la meta'
/// che dice di che collezione fa parte — su una figurina vera c'e' sempre, ed e'
/// sempre uguale per tutte. Qui fa anche una seconda cosa: tiene il titolo e la
/// data, che davanti toglierebbero spazio alla foto.
class TrophyBack extends StatelessWidget {
  const TrophyBack({required this.challenge, required this.kind, super.key});

  final Challenge challenge;
  final TrophyKind kind;

  @override
  Widget build(BuildContext context) {
    return _Laminated(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          // **Nero pieno.** Il retro di una figurina non compete con la foto
          // davanti: e' il fondo su cui il marchio si stacca, e il nero e'
          // l'unico che lo fa senza portare un colore nuovo nell'app.
          color: Colors.black,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Il marchio come va sul nero: **"cra" bianco, "sy" rosso**. E'
              // il file vero ricolorato, non una scritta rifatta con un
              // carattere — quelle lettere sono disegnate, e un font ne darebbe
              // una imitazione.
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: CrasyWordmark(
                  size: 34,
                  alignment: Alignment.center,
                  onDark: true,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                kind.label,
                textAlign: TextAlign.center,
                style: context.texts.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 8,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                challenge.title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall?.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                AppDateUtils.formatItalianDate(challenge.endsAt),
                textAlign: TextAlign.center,
                style: context.texts.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 8,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// La cornice: il bordo rosso, il riflesso, l'ombra. Uguale sulle due facce.
class _Laminated extends StatelessWidget {
  const _Laminated({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: TrophyFront.ratio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          // **La cornice e' oro, e non e' un capriccio.** Il rosso qui dentro
          // vuol dire *premio in palio*: e' il colore di una cosa che si puo'
          // ancora vincere. Un trofeo e' il contrario — e' una cosa gia' vinta,
          // e merita il colore che in ogni gara del mondo vuol dire quello.
          //
          // Tre toni e non uno: un oro a tinta unita e' senape. Sono la luce
          // sullo spigolo, il corpo del metallo e l'ombra dal lato opposto,
          // ed e' quello che lo fa sembrare una cosa e non un rettangolo
          // giallo.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6DFA0), Color(0xFFC9A227), Color(0xFF8C6D1F)],
            stops: [0, 0.45, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                // Il riflesso: una diagonale chiara e appena accennata. Piu'
                // forte di cosi' sembra vetro, e una figurina non e' di vetro.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0, 0.42, 0.52, 1],
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La figurina che si gira in mano.
///
/// **Si trascina col dito e continua a girare**, non fa un ribaltamento e
/// basta: e' la differenza fra un'animazione e un oggetto. Lasciandola, si
/// ferma sulla faccia piu' vicina — nessuno vuole restare con una carta di
/// taglio — e la spinta del dito conta, quindi un colpo secco la fa fare piu' di
/// un giro come farebbe una carta vera.
///
/// Il tocco resta la strada semplice: mezzo giro, e si vede il dietro.
class FlippableTrophy extends StatefulWidget {
  const FlippableTrophy({
    required this.challenge,
    required this.kind,
    super.key,
  });

  final Challenge challenge;
  final TrophyKind kind;

  @override
  State<FlippableTrophy> createState() => _FlippableTrophyState();
}

class _FlippableTrophyState extends State<FlippableTrophy>
    with SingleTickerProviderStateMixin {
  /// Senza limiti, perche' l'angolo non ne ha: si puo' girare all'infinito
  /// nella stessa direzione, come si fa con una carta vera fra le dita.
  late final AnimationController _angolo = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _angolo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _mezzoGiro,
      onHorizontalDragStart: (_) => _angolo.stop(),
      onHorizontalDragUpdate: (dettagli) {
        // Un centimetro di dito, mezzo giro scarso: piu' lento sembra
        // appiccicoso, piu' veloce non si riesce a fermarla dove si vuole.
        _angolo.value += dettagli.delta.dx * 0.012;
      },
      onHorizontalDragEnd: (dettagli) {
        final spinta = dettagli.primaryVelocity ?? 0;
        _fermaSullaFaccia(_angolo.value + spinta * 0.0012);
      },
      child: AnimatedBuilder(
        animation: _angolo,
        builder: (context, _) {
          final angolo = _angolo.value;
          final davanti = math.cos(angolo) >= 0;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              // La prospettiva: senza questa riga la carta non gira, si
              // schiaccia. E' la distanza dell'occhio dalla scena.
              ..setEntry(3, 2, 0.0013)
              ..rotateY(angolo),
            child: davanti
                ? TrophyFront(challenge: widget.challenge, kind: widget.kind)
                : Transform(
                    alignment: Alignment.center,
                    // Il retro va rigirato su se stesso, o si vedrebbe
                    // specchiato: e' dietro, quindi lo stiamo guardando dalla
                    // parte sbagliata.
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: TrophyBack(
                      challenge: widget.challenge,
                      kind: widget.kind,
                    ),
                  ),
          );
        },
      ),
    );
  }

  void _mezzoGiro() => _fermaSullaFaccia(_angolo.value + math.pi);

  /// Si posa sulla faccia piu' vicina a [meta].
  void _fermaSullaFaccia(double meta) {
    final faccia = (meta / math.pi).roundToDouble() * math.pi;

    _angolo.animateTo(
      faccia,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }
}

/// La bacheca: le figurine due per riga.
///
/// **Due e non tre.** Con tre stanno in un quadrato di due dita, e a quella
/// misura di una figurina non si vede niente: ne' la foto, ne' il valore, ne'
/// il bordo. Sono poche per definizione — sono i premi, non le partecipazioni —
/// quindi vale la pena che si vedano.
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
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: TrophyFront.ratio,
      ),
      itemCount: challenges.length,
      itemBuilder: (context, index) {
        final challenge = challenges[index];

        return GestureDetector(
          onTap: () => showTrophy(context, challenge: challenge, kind: kind),
          behavior: HitTestBehavior.opaque,
          child: TrophyFront(challenge: challenge, kind: kind),
        );
      },
    );
  }
}

/// La figurina grande, girabile, con sotto tutto quello che c'era dietro.
///
/// Serve a **rimettere la foto nel suo contesto**. Sei mesi dopo, di una gara
/// non ci si ricorda niente — cosa chiedeva, quanto era in palio, chi l'aveva
/// lanciata, quante fiamme aveva preso. Senza queste righe il trofeo e' una foto
/// qualunque nel proprio telefono; con queste righe e' una cosa che e' successa.
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

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.66,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SizedBox(
                width: 230,
                child: FlippableTrophy(challenge: challenge, kind: kind),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Che si giri non si vede: una carta ferma sembra un'immagine.
            // Una riga sola, piccola, e chi vuole prova.
            Center(
              child: Text(
                'TRASCINALA PER GIRARLA',
                style: texts.labelSmall?.copyWith(
                  color: palette.textFaint,
                  fontSize: 9,
                ),
              ),
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
              _Line(
                label: 'L\'ha fatta',
                value: '@${challenge.winnerUsername}',
              ),
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
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
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
