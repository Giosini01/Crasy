import 'dart:math' as math;

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/media_frame.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/duel_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

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
  ///
  /// La parola e' **lanciata**, che e' quella che l'app usa dappertutto —
  /// "lancia una challenge", "chi l'ha lanciata". Prima c'era *comandata*, che
  /// diceva la cosa giusta con il tono sbagliato: chi mette i soldi non comanda
  /// nessuno, propone una cosa da fare e la paga.
  commissioned('LANCIATA', 'HAI FATTO FARE');

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
          // **Senza foto la figurina ha comunque una faccia.**
          //
          // `MediaFrame` davanti a un indirizzo vuoto sparisce del tutto — ed
          // e' giusto ovunque tranne che qui: dentro una cornice dorata
          // lasciava un buco, cioe' esattamente l'aria di un'immagine che non
          // si e' caricata, proprio dove si sta guardando se qualcuno ha
          // davvero vinto dei soldi.
          //
          // Succedeva per una ragione precisa e adesso riparata: le gare
          // chiuse dal server non si ricopiavano dentro la foto del vincitore
          // (vedi `closeChallenge` in `functions/index.js`), e quarantotto ore
          // dopo la partecipazione da cui prenderla non c'era piu'. Quelle
          // vecchie restano senza, e per loro qui c'e' il fondo scuro con il
          // marchio — una figurina **senza fotografia**, che e' una cosa
          // diversa da una figurina rotta.
          if (MediaFrame.hasMedia(challenge.winnerMediaUrl))
            MediaFrame(
              url: challenge.winnerMediaUrl,
              video: challenge.winnerMediaKind.isVideo,
              aspectRatio: ratio,
              radius: AppRadius.sm,
            )
          else
            const _NoPhoto(),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              // **Chi vince legge quello che ha incassato**, non il
                              // numero della vetrina: il premio meno la percentuale
                              // di CRASY. Chi ha commissionato legge quanto ha messo,
                              // perche' e' quello che ha speso.
                              // Una sfida d'onore vinta non ha pagato niente:
                              // scritta come le altre diventerebbe un trofeo da
                              // `€0,00`, che e' il modo piu' rapido di far sembrare
                              // una vittoria una perdita. Al posto della cifra si
                              // scrive cos'era. Con dei soldi in palio invece la
                              // cifra c'e', ed e' quella che si legge: il trofeo dice
                              // sempre cosa si e' portato a casa.
                              challenge.isDuel && challenge.prizeCents == 0
                                  ? 'ONORE'
                                  : AppMoney.format(
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
                        ),
                        // **Con quante fiamme l'ha vinta.**
                        //
                        // Era l'unica cosa che mancava per capire *come* e'
                        // andata: la cifra dice quanto valeva la gara, il
                        // numero qui dice quanta gente ha alzato la mano per
                        // quella foto. Una vittoria da due fiamme e una da
                        // ottanta valgono gli stessi soldi e non sono la
                        // stessa cosa, e sei mesi dopo e' l'unico modo per
                        // ricordarsene.
                        //
                        // A zero non si scrive: le gare chiuse prima che il
                        // conteggio finisse dentro il documento non ce l'hanno,
                        // e uno zero li' direbbe "non e' piaciuta a nessuno"
                        // di una foto che magari aveva vinto a mani basse.
                        if (challenge.winnerVotes > 0) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 12,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 1),
                                Text(
                                  '${challenge.winnerVotes}',
                                  style: context.texts.labelSmall?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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

/// Il vetro della figurina quando la fotografia non c'e'.
///
/// Fondo scuro e marchio in mezzo, come il dietro della carta. Non e' un
/// segnaposto: e' la faccia che ha una figurina di una gara vinta prima che
/// esistesse l'abitudine di conservarne lo scatto. Il valore e la scritta
/// VINTA restano dov'erano, sulla fascia in basso, e sono quelli che contano.
class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF141414)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: CrasyWordmark(
              size: 30,
              alignment: Alignment.center,
              onDark: true,
            ),
          ),
        ),
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
          // **Oro come la cornice, non nero.** Il retro e la cornice sono la
          // stessa cosa vista da due parti: fatti di due materiali diversi
          // sembrano due oggetti incollati insieme. Qui il metallo continua,
          // e la figurina diventa una cosa sola.
          //
          // Gli stessi tre toni della cornice ma girati al contrario — chiaro
          // in basso a destra invece che in alto a sinistra: e' il dietro, e la
          // luce che lo colpisce viene dall'altra parte.
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [Color(0xFFF6DFA0), Color(0xFFC9A227), Color(0xFF8C6D1F)],
            stops: [0, 0.45, 1],
          ),
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
          // Cinque toni invece di tre. I due aggiunti sono il **colpo di luce**
          // appena dopo lo spigolo e il **rimbalzo** in fondo: sono le due cose
          // che un metallo fa e una tinta piatta no. Un oro a tre toni e' una
          // sfumatura; a cinque comincia a sembrare una superficie curva.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF3CF),
              Color(0xFFF6DFA0),
              Color(0xFFC9A227),
              Color(0xFF8C6D1F),
              Color(0xFFB8912B),
            ],
            stops: [0, 0.18, 0.5, 0.86, 1],
          ),
          // **Due ombre, non una.** Una sola ombra sfocata fa galleggiare
          // l'oggetto senza appoggiarlo: manca la riga scura e stretta subito
          // sotto il bordo, che e' quella che dice dove la cosa **tocca**. La
          // prima e' il contatto, la seconda e' l'aria attorno.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          // Un punto in piu' di cornice. Sembra niente scritto qui, e su una
          // figurina larga due centimetri e' la differenza fra un bordo e una
          // lastra: lo spessore e' cio' che si guarda per capire se una cosa e'
          // fatta di qualcosa.
          padding: const EdgeInsets.all(6),
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
                          Colors.white.withValues(alpha: 0.26),
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // **L'incavo: la foto sta sotto la cornice, non accanto.**
                //
                // E' il pezzo che mancava perche' la figurina sembrasse spessa.
                // L'oro e la foto si toccavano su una linea netta, e due
                // superfici che si toccano senza ombra stanno sullo stesso
                // piano: sembravano due colori affiancati, non un vetro dentro
                // un telaio.
                //
                // Qui c'e' un filetto scuro tutto attorno — il taglio — e una
                // velatura che scende dal bordo di sopra, che e' l'ombra che la
                // cornice fa cadere sulla foto. Basta quella per spostare la
                // foto **sotto** l'oro, e con lei tutta la figurina prende
                // spessore.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.32),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withValues(alpha: 0.24),
                          Colors.black.withValues(alpha: 0),
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
    this.fronte,
    this.retro,
    super.key,
  });

  final Challenge challenge;
  final TrophyKind kind;

  /// Cosa si vede dietro, quando non e' il retro della figurina.
  ///
  /// La targa lo cambia: il suo davanti porta gia' il marchio, il titolo e la
  /// data, e un retro che ripete le stesse tre cose rende il giro un gesto che
  /// non mostra niente.
  final Widget? retro;

  /// Cosa si vede davanti, quando non e' la figurina.
  ///
  /// Serve alla targa: gira con la stessa mano — stessa prospettiva, stessa
  /// inerzia, stesso mezzo giro al tocco — perche' il gesto e' quello che si e'
  /// gia' imparato sulle figurine, e due oggetti sulla stessa bacheca che si
  /// girano in due modi diversi sono due cose da imparare invece di una.
  final Widget? fronte;

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
                ? widget.fronte ??
                      TrophyFront(
                        challenge: widget.challenge,
                        kind: widget.kind,
                      )
                : Transform(
                    alignment: Alignment.center,
                    // Il retro va rigirato su se stesso, o si vedrebbe
                    // specchiato: e' dietro, quindi lo stiamo guardando dalla
                    // parte sbagliata.
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child:
                        widget.retro ??
                        TrophyBack(
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
    // **La targa ha la forma della figurina.** Sono due oggetti diversi e si
    // riconoscono al primo sguardo — una ha una foto dentro, l'altra e' metallo
    // scritto — ma stanno sulla stessa parete, e una parete con due formati
    // diversi non e' una collezione: e' un disordine.
    final targhe = kind == TrophyKind.commissioned;

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

        // **Quello che si e' fatto fare non e' una figurina: e' una targa.**
        //
        // Una figurina e' la foto di chi ha vinto dentro una cornice, e quella
        // foto e' sua: rimetterla sulla bacheca di chi ha solo *chiesto* la
        // cosa vuol dire prendersi il merito del lavoro di un altro, e per
        // giunta mettere la stessa immagine su due profili diversi.
        //
        // Vale per tutte e due le specie di prova — la sfida a un amico e la
        // gara aperta a tutti — perche' da questa parte sono la stessa cosa:
        // roba che hai fatto fare a qualcuno.
        //
        // **Il tocco non porta alla missione.** Apre la targa grande, con
        // dentro cos'era e com'e' finita, e si chiude li': da una bacheca non
        // si esce, si guarda.
        return GestureDetector(
          onTap: () => showTrophy(context, challenge: challenge, kind: kind),
          behavior: HitTestBehavior.opaque,
          child: targhe
              ? CommissionedTrophy(challenge: challenge)
              : TrophyFront(challenge: challenge, kind: kind),
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
            // **Aperta, una targa resta una targa.**
            //
            // Qui c'era la figurina girabile, con dentro la foto di chi ha
            // vinto: la stessa cosa che si e' tolta dalla bacheca, che
            // ricompariva al primo tocco. E una targa non si gira — dietro una
            // targa c'e' il muro.
            Center(
              child: SizedBox(
                width: 230,
                child: kind == TrophyKind.commissioned
                    ? CommissionedTrophy(challenge: challenge, grande: true)
                    : FlippableTrophy(
                        challenge: challenge,
                        kind: kind,
                        // **La targa gira come la figurina.** Davanti c'e' la
                        // piastra incisa invece della foto, dietro c'e' lo stesso
                        // retro: il gesto e' quello che si e' gia' imparato, e due
                        // oggetti sulla stessa bacheca che si girano in due modi
                        // diversi sono due cose da imparare invece di una.
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
              value: challenge.isDuel && challenge.prizeCents == 0
                  ? 'ONORE'
                  : AppMoney.format(
                      kind.isWon ? challenge.payoutCents : challenge.prizeCents,
                    ),
              accent: true,
            ),
            // Chi ha vinto sa gia' chi e'. Chi ha commissionato spesso no: e' la
            // riga che trasforma "una foto" in "la foto di quella persona".
            //
            // **I due nomi si toccano e portano al profilo.** Un `@nome` scritto
            // e non cliccabile e' il posto piu' facile dove far arenare
            // qualcuno: si e' appena scoperto chi ha fatto quella foto o chi ha
            // messo quei soldi, e l'unico modo di saperne di piu' sarebbe
            // ricordarsi il nome, chiudere, aprire la ricerca e riscriverlo.
            if (!kind.isWon && challenge.winnerUsername.isNotEmpty)
              _Line(
                label: 'L\'ha fatta',
                value: '@${challenge.winnerUsername}',
                onTap: challenge.winnerUserId.isEmpty
                    ? null
                    : () => _apriProfilo(context, challenge.winnerUserId),
              ),
            if (kind.isWon && challenge.hasCreator)
              _Line(
                label: 'L\'aveva chiesta',
                value: '@${challenge.createdByUsername}',
                onTap: challenge.createdByUserId.isEmpty
                    ? null
                    : () => _apriProfilo(context, challenge.createdByUserId),
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

/// Va al profilo di qualcuno **chiudendo prima la figurina**.
///
/// Il router si prende prima della chiusura, non dopo: dopo il `pop` il pezzo di
/// albero a cui appartiene questo contesto e' gia' smontato, e cercarci dentro
/// il router e' il modo classico di far esplodere una schermata che sembrava
/// funzionare.
///
/// E si chiude, invece di aprire il profilo sopra: un profilo che spunta sotto
/// una figurina rimasta aperta lascia due cose da chiudere per tornare indietro,
/// e la seconda nessuno se l'aspetta.
void _apriProfilo(BuildContext context, String userId) {
  final router = GoRouter.of(context);

  Navigator.of(context).pop();
  router.push(AppRoutes.userProfileOf(userId));
}

/// Una riga del retro: l'etichetta a sinistra, il valore a destra.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.accent = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool accent;

  /// Se c'e', la riga si tocca e il valore si colora: senza il colore, un nome
  /// cliccabile e uno che non lo e' hanno lo stesso identico aspetto, e a
  /// scoprire la differenza si arriva solo per caso.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final riga = Padding(
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
                  : onTap != null
                  ? context.texts.bodyMedium?.copyWith(color: palette.accent)
                  : context.texts.bodyMedium,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return riga;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: riga,
    );
  }
}

/// **Il trofeo di chi la prova l'ha fatta fare: una coppa, non una foto.**
///
/// Una figurina e' la foto di chi ha vinto dentro una cornice, e quella foto e'
/// sua: rimetterla sulla bacheca di chi ha solo *chiesto* la cosa vuol dire
/// prendersi il merito del lavoro di un altro, e per giunta mettere la stessa
/// immagine su due profili diversi.
///
/// Qui c'e' l'oggetto che si da' a chi organizza, non a chi corre: una coppa,
/// con sotto cosa ha fatto fare e quanto ci ha messo. La coppa e' **disegnata**
/// e non e' un'emoji — vedi `_CupPainter`: deve essere d'oro come il resto
/// della bacheca, e l'oro di un'emoji e' quello del sistema operativo, diverso
/// su ogni telefono e uguale a quello di qualunque altra app.
///
/// La cifra ha il corpo con cui una figurina scrive quanto si e' incassato,
/// perche' e' lo stesso numero visto dalle due parti: quello che uno ha preso,
/// e quello che un altro ha messo perche' lo prendesse.
class CommissionedTrophy extends StatelessWidget {
  const CommissionedTrophy({
    required this.challenge,
    this.grande = false,
    super.key,
  });

  final Challenge challenge;

  /// Aperta a tutta finestra, invece che nella griglia della bacheca.
  ///
  /// Cambia solo quanto sono grandi le scritte: nella griglia una targa e'
  /// larga mezzo schermo e deve stare leggibile in poco, aperta ha il triplo
  /// dello spazio — e tenere lo stesso corpo vorrebbe dire una targa grande con
  /// dentro una scritta da francobollo.
  final bool grande;

  /// Le proporzioni della coppa, sempre le stesse.
  ///
  /// **Senza questa riga il disegno si stira.** Il pittore mappa le sue misure
  /// sulla larghezza e sull'altezza della scatola che gli capita: in una cella
  /// alta e stretta la coppa si allunga, in una larga si schiaccia — e sono due
  /// oggetti diversi, non lo stesso oggetto piu' grande. Fissate qui, la scatola
  /// puo' essere quello che vuole: la coppa resta questa, e cambia solo quanto
  /// spazio ha intorno.
  static const double cupRatio = 0.86;

  /// Di quanto crescono le scritte quando la coppa e' aperta.
  ///
  /// **Un e mezzo e non due.** Le scritte stanno sotto la coppa e le tolgono
  /// spazio: ingrandite troppo, aprire la targa faceva **rimpicciolire** la
  /// coppa invece di ingrandirla — che e' il contrario di quello che uno si
  /// aspetta toccandola.
  double get _scala => grande ? 1.45 : 1;

  /// L'occhiello in cima: dice di che specie e' la prova.
  String get _intestazione {
    if (challenge.isDuel) {
      return 'PROVA D\'ONORE';
    }

    return challenge.isForFriends ? 'HAI FATTO FARE · AMICI' : 'HAI FATTO FARE';
  }

  /// Il riflesso che trasforma una scritta scura in una scritta **scavata**.
  ///
  /// Una copia chiarissima spostata di un punto in basso a destra: e' la luce
  /// che batte sul bordo di sotto del solco. Non e' un'ombra — e' il contrario
  /// di un'ombra, e senza di lei le lettere sembrano stampate sopra l'oro
  /// invece che dentro.

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;
    final (titolo, esito) = _cosaCEScritto();

    // **Niente cornice.** Una coppa dentro una carta e' la foto di una coppa;
    // una coppa da sola, appoggiata sulla sua ombra, e' un oggetto sulla
    // mensola — che e' quello che un trofeo deve sembrare.
    return AspectRatio(
      aspectRatio: TrophyFront.ratio,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6 * _scala),
              // **Le proporzioni della coppa non dipendono dalla scatola.**
              // Centrata dentro lo spazio che ha, con le sue misure: cosi' e'
              // identica nella bacheca e aperta, e cambia solo quanto e'
              // grande — che e' l'unica cosa che deve cambiare.
              child: Center(
                child: AspectRatio(
                  aspectRatio: cupRatio,
                  child: grande ? const _SpinningCup() : const _Cup(angolo: 0),
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xs * _scala),
          // **Di che specie e' questa prova.** Una missione aperta a chiunque,
          // una per il proprio gruppo e una sfida a una persona sola non sono
          // la stessa cosa: cambia chi poteva parteciparci.
          Text(
            _intestazione,
            textAlign: TextAlign.center,
            style: texts.labelSmall?.copyWith(
              color: context.palette.textFaint,
              fontSize: 7 * _scala,
              letterSpacing: 1.9,
            ),
          ),
          SizedBox(height: 2 * _scala),
          Text(
            titolo.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: texts.labelSmall?.copyWith(
              color: context.palette.textPrimary,
              fontSize: 9.5 * _scala,
              letterSpacing: 0.4,
            ),
          ),
          // **Quanto e' costata, con il carattere delle figurine.** E' lo
          // stesso corpo con cui una figurina scrive quanto si e' incassato,
          // perche' e' lo stesso numero visto dalle due parti. A zero non si
          // scrive: una missione gratis non ha cifre, e uno zero sembrerebbe un
          // guasto.
          if (challenge.prizeCents > 0) ...[
            SizedBox(height: 2 * _scala),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppMoney.format(challenge.prizeCents),
                style: texts.headlineSmall?.copyWith(
                  color: _CupPainter._scuro,
                  fontSize: 15 * _scala,
                  height: 1,
                ),
              ),
            ),
          ],
          SizedBox(height: 2 * _scala),
          Text(
            esito,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: texts.labelSmall?.copyWith(
              color: context.palette.textFaint,
              fontSize: 7 * _scala,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Cosa va scritto: il titolo, il nome, com'e' finita e il suo segno.
  ///
  /// **Le due specie di prova si scrivono nello stesso modo.** Una sfida a un
  /// amico e una gara aperta a tutti sono la stessa cosa vista da chi l'ha
  /// lanciata — una cosa che ha fatto fare a qualcuno — e cambia solo di chi e'
  /// il nome: il destinatario nell'una, chi ha vinto nell'altra.
  (String, String) _cosaCEScritto() {
    if (challenge.isDuel) {
      final state = challenge.duelStateAt(DateTime.now());

      final esito = switch (state) {
        DuelState.completed => 'SUPERATA',
        DuelState.notValid => 'NON VALIDA',
        DuelState.declined => 'RIFIUTATA',
        DuelState.expired => 'NON FATTA',
        DuelState.noVerdict => 'SENZA GIUDIZIO',
        DuelState.judging => 'DA GIUDICARE',
        _ => 'IN CORSO',
      };

      return (challenge.title, esito);
    }

    if (challenge.winnerUsername.isNotEmpty) {
      return (challenge.title, 'SUPERATA');
    }

    return (
      challenge.title,
      challenge.hasEndedAt(DateTime.now()) ? 'NESSUN VINCITORE' : 'IN CORSO',
    );
  }
}


/// **La coppa, disegnata.**
///
/// Non e' un'immagine e non e' un'emoji: e' una forma costruita a mano. Un'
/// emoji porta con se' il disegno del sistema operativo — diverso su ogni
/// telefono, e uguale a quello di qualunque altra app.
///
/// ## Perche' e' di plastica e non di metallo
///
/// La prima versione era oro lucido, con l'orizzonte riflesso e il puntino duro
/// della sorgente. Era corretta e sbagliata insieme: un metallo lucido **mostra
/// quello che ha intorno**, quindi ha bisogno di un intorno — in una griglia su
/// fondo bianco riflette il nulla, e resta una macchia gialla complicata.
///
/// Questa e' resa morbida: un oggetto **opaco**, arancione, con la luce che ci
/// scivola sopra invece di specchiarcisi. Ha tre sole regole, ed e' il motivo
/// per cui si legge anche grande come un francobollo:
///
/// - **niente spigoli**: ogni pezzo e' tondo o raccordato, e dove due pezzi si
///   toccano c'e' un'ombra morbida invece di una linea;
/// - **una luce sola, da sopra a sinistra**: tutti i chiari stanno da quella
///   parte, tutte le ombre dall'altra. Una seconda sorgente e' quello che fa
///   sembrare un disegno "sporco" senza che si capisca perche';
/// - **il colore cambia di tinta, non solo di quantita'**: le ombre vanno verso
///   il rosso e le luci verso il giallo, come fa la plastica vera. Schiarire e
///   scurire lo stesso arancione da' un oggetto di cartone.
class _CupPainter extends CustomPainter {
  const _CupPainter({this.angolo = 0});

  /// Di quanto e' girata, in radianti.
  ///
  /// **Una coppa girata resta identica di sagoma**, ed e' quello che la rende
  /// una cosa tonda: un cilindro visto da qualunque parte ha lo stesso profilo.
  /// A cambiare sono tre cose, e sono quelle con cui l'occhio misura la
  /// rotazione di un oggetto liscio — dove batte la luce, dove stanno i manici,
  /// e dov'e' finita la stella.
  final double angolo;

  /// Quanto la faccia illuminata e' girata verso di noi: da `-1` a `1`.
  double get _fronte => math.cos(angolo);

  // L'arancione, dalle luci gialle alle ombre rosse.
  static const Color _chiaro = Color(0xFFFFB259);
  static const Color _medio = Color(0xFFFB8C20);
  static const Color _scuro = Color(0xFFE06A00);
  static const Color _ombra = Color(0xFFB04A00);

  // **Il basamento e' nero, non bianco.**
  //
  // Il bianco era un pezzo che non c'entrava niente: non e' un colore di
  // CRASY, non e' un materiale che si accompagni all'oro, e sotto un oggetto
  // caldo faceva l'effetto di un sottobicchiere. Il nero e' il colore su cui
  // sta scritta tutta l'app, e sotto una coppa e' il marmo dei basamenti veri.
  static const Color _neroLuce = Color(0xFF3A3A3E);
  static const Color _neroMedio = Color(0xFF1C1C1F);
  static const Color _neroOmbra = Color(0xFF0A0A0B);

  /// Il rosso di CRASY: **a gocce, non a pennellate.**
  ///
  /// Un trofeo tutto rosso non e' un trofeo, e' un oggetto rosso. Il rosso qui
  /// dentro vuol dire una cosa sola in tutta l'app — *questo conta* — e vale
  /// finche' resta raro: due fili sottili, uno sul bordo e uno sul basamento,
  /// bastano a dire di chi e' questo oggetto.
  static const Color _rosso = Color(0xFFFA0000);

  /// La sfumatura di un pezzo tondo, con la luce che segue la rotazione.
  Shader _plastica(Rect area) {
    final centro = (0.36 + _fronte * 0.20).clamp(0.10, 0.86);

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [_scuro, _chiaro, _medio, _scuro, _ombra],
      stops: [
        0,
        (centro - 0.06).clamp(0.02, 0.9),
        (centro + 0.20).clamp(0.05, 0.94),
        0.88,
        1,
      ],
    ).createShader(area);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _ombraATerra(canvas, w, h);
    _manici(canvas, w, h);
    _vaso(canvas, w, h);
    _bordo(canvas, w, h);
    _stelo(canvas, w, h);
    _base(canvas, w, h);
  }

  /// L'ombra sul ripiano: la prima cosa da disegnare e l'ultima che si nota.
  /// E' quella che appoggia la coppa invece di lasciarla a mezz'aria.
  void _ombraATerra(Canvas canvas, double w, double h) {
    // **Due ombre, non una.** Quella larga e sfumata e' l'aria attorno; quella
    // stretta e scura, appiccicata sotto il bordo, e' il **contatto** — il
    // punto in cui l'oggetto tocca. Senza la seconda ogni cosa galleggia di un
    // paio di millimetri, e si vede anche senza saperlo dire.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.53, h * 0.955),
        width: w * 0.74,
        height: h * 0.055,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.928),
        width: w * 0.50,
        height: h * 0.022,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  /// I due manici: anelli spessi e arrotondati, attaccati ai fianchi.
  ///
  /// **Si disegnano prima del vaso, ed e' tutto il trucco**: cosi' il vaso ci
  /// passa sopra e li taglia dove si attaccano, che e' come si vedono davvero.
  /// Fatti dopo, resterebbero due anelli appoggiati sopra.
  ///
  /// E girano con la coppa: stanno ai due lati opposti, quindi uno viene avanti
  /// e l'altro va dietro, a meta' giro si scambiano di posto, e di taglio si
  /// assottigliano fino quasi a sparire — l'istante in cui si vede che
  /// l'oggetto ha uno spessore.
  void _manici(Canvas canvas, double w, double h) {
    for (final verso in const [-1.0, 1.0]) {
      final apertura = verso * _fronte;
      final spessore = w * 0.085 * (0.3 + apertura.abs() * 0.7);
      final attacco = w * (0.5 + apertura * 0.22);
      final fuori = w * (0.5 + apertura * 0.47);

      final path = Path()
        ..moveTo(attacco, h * 0.27)
        ..cubicTo(fuori, h * 0.28, fuori, h * 0.50, attacco, h * 0.49);

      final area = Rect.fromLTRB(
        math.min(attacco, fuori) - spessore,
        h * 0.26,
        math.max(attacco, fuori) + spessore,
        h * 0.50,
      );

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spessore
          ..strokeCap = StrokeCap.round
          ..shader = _plastica(area),
      );

      // **L'ombra dove il manico entra nel vaso.** Due pezzi che si toccano
      // senza un buio in mezzo stanno sullo stesso piano: sono due colori
      // affiancati, non un oggetto con delle parti. Sono due macchioline, e
      // sono quello che attacca i manici invece di appoggiarli.
      for (final alto in const [0.28, 0.48]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(attacco, h * alto),
            width: spessore * 1.5,
            height: spessore * 1.1,
          ),
          Paint()
            ..color = _ombra.withValues(alpha: 0.35 * apertura.abs())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  /// Il vaso: la coppa vera e propria.
  void _vaso(Canvas canvas, double w, double h) {
    final area = Rect.fromLTWH(w * 0.22, h * 0.20, w * 0.56, h * 0.42);

    // Fianchi che rientrano dolcemente e fondo tondo: e' la pancia della coppa,
    // e un fondo piatto la farebbe sembrare un bicchiere.
    final path = Path()
      ..moveTo(w * 0.22, h * 0.20)
      ..cubicTo(w * 0.235, h * 0.44, w * 0.32, h * 0.58, w * 0.42, h * 0.605)
      ..cubicTo(w * 0.47, h * 0.615, w * 0.53, h * 0.615, w * 0.58, h * 0.605)
      ..cubicTo(w * 0.68, h * 0.58, w * 0.765, h * 0.44, w * 0.78, h * 0.20)
      ..close();

    canvas.drawPath(path, Paint()..shader = _plastica(area));

    canvas.save();
    canvas.clipPath(path);

    // **La luce morbida in alto.** Su un oggetto opaco non c'e' un puntino
    // duro: c'e' una zona chiara larga, con i bordi sfumati. E' la differenza
    // fra plastica e vetro.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * (0.42 + _fronte * 0.10), h * 0.30),
        width: w * 0.30,
        height: h * 0.22,
      ),
      Paint()
        ..color = _chiaro.withValues(
          alpha: (0.5 * (0.35 + _fronte.abs() * 0.65)).clamp(0.0, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // E il buio che rientra sul fianco che gira via: e' la brusca con cui una
    // superficie dice che sta curvando, non finendo.
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x40B04A00), Colors.transparent, Color(0x73B04A00)],
          stops: [0, 0.3, 1],
        ).createShader(area),
    );

    // **La luce di rimbalzo.** Sul lato in ombra, proprio sul bordo, torna un
    // filo di chiaro: e' la luce che rimbalza da quello che sta intorno. E'
    // debole e sottile, ma senza di lei il lato scuro sembra tagliato via
    // invece che girato — e' il dettaglio che piu' di tutti separa un disegno
    // da un oggetto.
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.transparent, Color(0x59FFB259)],
          stops: [0, 0.9, 1],
        ).createShader(area),
    );

    // L'occlusione in fondo alla pancia: dove la curva si chiude, la luce non
    // arriva piu'. E' lo stesso motivo per cui l'incavo di un cucchiaio e'
    // scuro anche sotto una lampada.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.625),
        width: w * 0.42,
        height: h * 0.09,
      ),
      Paint()
        ..color = _ombra.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.restore();
  }

  /// Il bordo in cima: una fascia tonda, un pezzo a se'.
  ///
  /// Non e' un dettaglio decorativo — e' l'unica cosa che dice che la coppa e'
  /// **aperta**. Senza, la sagoma e' un vaso pieno.
  void _bordo(Canvas canvas, double w, double h) {
    final fascia = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.185, h * 0.145, w * 0.63, h * 0.075),
      Radius.circular(h * 0.04),
    );

    canvas.drawRRect(fascia, Paint()..shader = _plastica(fascia.outerRect));

    // **Il filo rosso sotto la fascia.** Un solo tratto sottile: e' la firma,
    // e una firma larga non e' piu' una firma.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.208, w * 0.60, h * 0.011),
        Radius.circular(h * 0.006),
      ),
      Paint()..color = _rosso,
    );

    // L'imboccatura: un'ellisse scura appena sopra la fascia. Poca, perche' su
    // un oggetto di plastica anche il buio e' morbido.
    final bocca = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.152),
      width: w * 0.58,
      height: h * 0.055,
    );

    canvas.drawOval(bocca, Paint()..color = _ombra);
    canvas.drawOval(
      bocca.deflate(w * 0.018),
      Paint()..color = const Color(0xFF8A3800),
    );

    // Il filo di luce sul labbro, solo dalla parte illuminata: tutto intorno
    // sarebbe una collana.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(bocca.left, bocca.top - h * 0.02, bocca.width, h * 0.03),
    );
    canvas.drawOval(
      bocca,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = _chiaro.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  /// Lo stelo e il piede che reggono il vaso.
  void _stelo(Canvas canvas, double w, double h) {
    final gambo = Rect.fromLTWH(w * 0.42, h * 0.60, w * 0.16, h * 0.12);

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.425, h * 0.60)
        ..cubicTo(w * 0.435, h * 0.66, w * 0.435, h * 0.70, w * 0.41, h * 0.735)
        ..lineTo(w * 0.59, h * 0.735)
        ..cubicTo(w * 0.565, h * 0.70, w * 0.565, h * 0.66, w * 0.575, h * 0.60)
        ..close(),
      Paint()..shader = _plastica(gambo),
    );

    // L'ombra che il vaso getta sullo stelo: e' quella a dire che il vaso sta
    // **sopra** e non davanti.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.615),
        width: w * 0.17,
        height: h * 0.035,
      ),
      Paint()
        ..color = _ombra.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Il piede: una fascia tonda schiacciata, come il bordo in cima. I due
    // pezzi si somigliano apposta — su un oggetto solo, le forme si ripetono.
    final piede = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.295, h * 0.725, w * 0.41, h * 0.055),
      Radius.circular(h * 0.028),
    );

    canvas.drawRRect(piede, Paint()..shader = _plastica(piede.outerRect));
  }

  /// La base: il cilindro bianco su cui la coppa sta in piedi.
  ///
  /// **Bianca e non arancione**, e non e' un vezzo: un oggetto di un colore
  /// solo non ha peso. Il bianco freddo sotto l'arancione caldo separa la cosa
  /// dal suo sostegno, e da' alla coppa qualcosa su cui appoggiare.
  void _base(Canvas canvas, double w, double h) {
    final corpo = Rect.fromLTWH(w * 0.235, h * 0.805, w * 0.53, h * 0.115);

    // Il fianco del cilindro: chiaro a sinistra dove batte la luce, grigio a
    // destra. E' la stessa sfumatura del resto, in un'altra tinta.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        corpo,
        bottomLeft: Radius.circular(w * 0.10),
        bottomRight: Radius.circular(w * 0.10),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_neroMedio, _neroLuce, _neroMedio, _neroOmbra],
          stops: [0, 0.28, 0.66, 1],
        ).createShader(corpo),
    );

    // L'ombra del piede sul basamento, prima di ogni altra cosa: senza, la
    // coppa e' posata su un disegno di basamento.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.792),
        width: w * 0.40,
        height: h * 0.045,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Il filo rosso attorno al basamento, appena sotto il piano: e' l'altra
    // goccia, e le due si rispondono da una parte all'altra dell'oggetto.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.235, h * 0.828, w * 0.53, h * 0.012),
      Paint()..color = _rosso,
    );

    // Il coperchio: l'ellisse in cima, piu' chiara perche' guarda in su.
    final piano = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.805),
      width: w * 0.53,
      height: h * 0.085,
    );

    canvas.drawOval(
      piano,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [_neroLuce, _neroMedio],
        ).createShader(piano),
    );

    // L'ombra della coppa sul piano: poca e sfocata, ma e' quella che dice che
    // la coppa sta **sopra** la base e non davanti.
    canvas.save();
    canvas.clipRect(piano);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.52, h * 0.80),
        width: w * 0.34,
        height: h * 0.05,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CupPainter oldDelegate) => oldDelegate.angolo != angolo;
}

/// **La coppa che gira, a trecentosessanta gradi.**
///
/// Si trascina con il dito e continua per inerzia, come una cosa appoggiata su
/// un piatto girevole; un tocco le da' mezzo giro. Da ferma gira piano da sola:
/// e' il modo in cui un oggetto in vetrina dice che e' un oggetto, e non un
/// disegno.
///
/// **Non e' una carta che si ribalta.** Una carta ha un davanti e un dietro, e
/// a meta' giro mostra lo spessore di un foglio. Una coppa e' tonda: girandola
/// la sagoma resta la stessa, e a cambiare sono la luce che scorre sul fianco e
/// i manici che si chiudono di taglio e riaprono dall'altra parte — vedi
/// `_CupPainter.angolo`.
class _SpinningCup extends StatefulWidget {
  const _SpinningCup();

  @override
  State<_SpinningCup> createState() => _SpinningCupState();
}

class _SpinningCupState extends State<_SpinningCup>
    with SingleTickerProviderStateMixin {
  /// L'angolo, senza limiti: si gira all'infinito nella stessa direzione.
  double _angolo = 0;

  /// La velocita' con cui sta girando, in radianti al secondo.
  double _velocita = 0.6;

  /// Se c'e' un dito sopra: mentre la si tiene, l'inerzia non conta.
  bool _presa = false;

  late final Ticker _ticker = createTicker(_passo);
  Duration _ultimo = Duration.zero;

  /// La rotazione lenta che la coppa fa da sola, quando nessuno la tocca.
  static const double _dolce = 0.6;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _passo(Duration adesso) {
    final dt = (adesso - _ultimo).inMicroseconds / 1e6;
    _ultimo = adesso;

    if (_presa || dt <= 0 || dt > 0.1) {
      return;
    }

    setState(() {
      _angolo += _velocita * dt;
      // L'inerzia si spegne piano e torna alla rotazione lenta: una spinta
      // forte fa fare tre giri e poi la coppa riprende a girare da sola,
      // invece di fermarsi di colpo.
      _velocita += (_dolce - _velocita) * (1 - math.exp(-dt * 1.6));
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _velocita += math.pi * 1.6),
      onHorizontalDragStart: (_) => _presa = true,
      onHorizontalDragUpdate: (dettagli) =>
          setState(() => _angolo += dettagli.delta.dx * 0.018),
      onHorizontalDragEnd: (dettagli) {
        _presa = false;
        _velocita = (dettagli.primaryVelocity ?? 0) * 0.012;
      },
      child: _Cup(angolo: _angolo),
    );
  }
}


/// **La coppa con il marchio sopra.**
///
/// Il disegno e il marchio sono due cose diverse e vanno tenute separate: la
/// coppa e' una forma costruita a mano, il marchio e' **un file** — quelle
/// lettere sono disegnate una per una, e rifarle con un carattere ne darebbe
/// un'imitazione. Percio' l'immagine vera si appoggia sopra il disegno invece
/// di essere ridisegnata dentro.
///
/// **E gira insieme alla coppa**, che e' il pezzo che rende la rotazione
/// evidente: il resto e' simmetrico, quindi girandolo cambia solo la luce e a
/// occhio potrebbe sembrare un tremolio. Il marchio invece si vede passare —
/// scorre di lato, si stringe mentre va via di taglio, sparisce dietro e
/// ritorna. Da solo dice che l'oggetto ha un davanti e un dietro.
class _Cup extends StatelessWidget {
  const _Cup({required this.angolo});

  final double angolo;

  @override
  Widget build(BuildContext context) {
    final fronte = math.cos(angolo);
    final lato = math.sin(angolo);

    return LayoutBuilder(
      builder: (context, vincoli) {
        final w = vincoli.maxWidth;
        final h = vincoli.maxHeight;

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _CupPainter(angolo: angolo)),
            ),
            // Sul retro non si vede: la coppa e' opaca.
            if (fronte > 0.02)
              Positioned(
                left: w * 0.5 + w * lato * 0.17 - w * 0.19,
                top: h * 0.315,
                width: w * 0.38,
                child: Transform(
                  alignment: Alignment.center,
                  // Stretto in orizzontale mentre gira via: e' lo stesso
                  // marchio visto di sbieco, incollato su una superficie tonda.
                  transform: Matrix4.identity()
                    ..scaleByDouble(fronte, 1, 1, 1),
                  child: Opacity(
                    opacity: (0.3 + fronte * 0.7).clamp(0.0, 1.0),
                    child: CrasyWordmark(
                      size: w * 0.30,
                      alignment: Alignment.center,
                      onDark: true,
                      // Su un trofeo il marchio non e' l'intestazione di una
                      // schermata: e' inciso su un oggetto, e una targhetta
                      // provvisoria li' sopra non ha senso.
                      beta: false,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
