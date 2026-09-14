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
              ? GoldPlaque(challenge: challenge)
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
                child: FlippableTrophy(
                  challenge: challenge,
                  kind: kind,
                  // **La targa gira come la figurina.** Davanti c'e' la
                  // piastra incisa invece della foto, dietro c'e' lo stesso
                  // retro: il gesto e' quello che si e' gia' imparato, e due
                  // oggetti sulla stessa bacheca che si girano in due modi
                  // diversi sono due cose da imparare invece di una.
                  fronte: kind == TrophyKind.commissioned
                      ? GoldPlaque(challenge: challenge, grande: true)
                      : null,
                  retro: kind == TrophyKind.commissioned
                      ? const PlaqueBack()
                      : null,
                ),
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

/// **La targa: la stessa lamina della figurina, con dentro una lastra incisa.**
///
/// Una figurina e' la foto di chi ha vinto dentro una cornice, e quella foto e'
/// sua: rimetterla sulla bacheca di chi ha solo *chiesto* la cosa vuol dire
/// prendersi il merito del lavoro di un altro, e per giunta mettere la stessa
/// immagine su due profili diversi. Una targa dice l'altra cosa, quella giusta:
/// **questa prova l'ho fatta fare io.**
///
/// ## Perche' riusa [_Laminated] invece di rifarsi la cornice
///
/// La prima versione si disegnava l'oro per conto suo, ed era brutta — un
/// rettangolo giallo con delle scritte sopra. Tutto quello che fa sembrare
/// vera una figurina non e' il colore: sono le **due ombre** (una corta, che
/// dice dove tocca, e una larga, che e' l'aria attorno), i **cinque toni**
/// dell'oro che curvano la superficie, il **riflesso in diagonale** e
/// soprattutto l'**incavo** — il filetto scuro che mette il contenuto *sotto*
/// la cornice invece che accanto. Sono gia' tutti li' dentro, gia' regolati, e
/// rifarli a mano vuol dire rifarli peggio.
///
/// Quindi la targa e' la figurina con un'altra faccia: al posto della foto una
/// lastra scura incisa, che e' esattamente come sono fatte le targhe vere —
/// cornice dorata, piastra scura, lettere chiare.
class GoldPlaque extends StatelessWidget {
  const GoldPlaque({required this.challenge, this.grande = false, super.key});

  final Challenge challenge;

  /// Aperta a tutta finestra, invece che nella griglia della bacheca.
  ///
  /// Cambia solo quanto sono grandi le scritte: nella griglia una targa e'
  /// larga mezzo schermo e deve stare leggibile in poco, aperta ha il triplo
  /// dello spazio — e tenere lo stesso corpo vorrebbe dire una targa grande con
  /// dentro una scritta da francobollo.
  final bool grande;

  /// Di quanto crescono le scritte quando la targa e' aperta.
  double get _scala => grande ? 1.9 : 1;

  /// L'occhiello in cima: dice di che specie e' la prova.
  String get _intestazione {
    if (challenge.isDuel) {
      return 'PROVA D\'ONORE';
    }

    return challenge.isForFriends ? 'MISSIONE · AMICI' : 'MISSIONE';
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
    final (titolo, esito, segno) = _cosaCEScritto();

    return _Laminated(
      child: DecoratedBox(
        // **La lastra.** Piu' chiara della cornice, non piu' scura: una
        // superficie piana prende piu' luce di un bordo smussato, ed e' il modo
        // in cui l'occhio capisce qual e' la parte dritta. Cornice e lastra sono
        // lo stesso metallo — una targa placcata e' un pezzo solo, e a separarle
        // c'e' la luce e basta.
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFBF0CF),
              Color(0xFFEBD293),
              Color(0xFFCFA94D),
            ],
            stops: [0, 0.48, 1],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sm * _scala),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Il marchio come va sul nero: **"cra" bianco, "sy" rosso**. E'
              // il file vero ricolorato, non una scritta rifatta con un
              // carattere — quelle lettere sono disegnate, e un font ne darebbe
              // un'imitazione.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: CrasyWordmark(
                  size: 34 * _scala,
                  alignment: Alignment.center,
                  onDark: true,
                ),
              ),
              SizedBox(height: AppSpacing.xs * _scala),
              // **Di che specie e' questa prova.**
              //
              // Una missione aperta a chiunque, una lanciata al proprio gruppo
              // e una sfida a una persona sola stanno tutte e tre in questa
              // bacheca, e da fuori si somigliavano. Non sono la stessa cosa:
              // cambia chi poteva parteciparci, e quindi cosa vuol dire averla
              // lanciata.
              Text(
                _intestazione,
                textAlign: TextAlign.center,
                style: texts.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 8 * _scala,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                titolo.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: texts.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 11 * _scala,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: AppSpacing.xxs * _scala),
              Text(
                AppDateUtils.formatItalianDate(challenge.endsAt),
                textAlign: TextAlign.center,
                style: texts.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 8 * _scala,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              // Com'e' finita, in fondo: e' la riga che si legge da lontano
              // scorrendo la bacheca.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(segno, style: TextStyle(fontSize: 11 * _scala)),
                  SizedBox(width: 4 * _scala),
                  Flexible(
                    child: Text(
                      esito,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 8.5 * _scala,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cosa va scritto: il titolo, il nome, com'e' finita e il suo segno.
  ///
  /// **Le due specie di prova si scrivono nello stesso modo.** Una sfida a un
  /// amico e una gara aperta a tutti sono la stessa cosa vista da chi l'ha
  /// lanciata — una cosa che ha fatto fare a qualcuno — e cambia solo di chi e'
  /// il nome: il destinatario nell'una, chi ha vinto nell'altra.
  (String, String, String) _cosaCEScritto() {
    if (challenge.isDuel) {
      final state = challenge.duelStateAt(DateTime.now());

      final (esito, segno) = switch (state) {
        DuelState.completed => ('SUPERATA', '🏆'),
        DuelState.notValid => ('NON VALIDA', '👎'),
        DuelState.declined => ('RIFIUTATA', '💩'),
        DuelState.expired => ('NON FATTA', '💩'),
        DuelState.noVerdict => ('SENZA GIUDIZIO', '⏳'),
        DuelState.judging => ('DA GIUDICARE', '⚖️'),
        _ => ('IN CORSO', '⏳'),
      };

      return (challenge.title, esito, segno);
    }

    if (challenge.winnerUsername.isNotEmpty) {
      return (
        challenge.title,
        challenge.prizeCents == 0
            ? 'SUPERATA'
            : 'SUPERATA · ${AppMoney.format(challenge.prizeCents)}',
        '🏆',
      );
    }

    return (
      challenge.title,
      challenge.hasEndedAt(DateTime.now()) ? 'NESSUN VINCITORE' : 'IN CORSO',
      challenge.hasEndedAt(DateTime.now()) ? '—' : '⏳',
    );
  }
}




/// Il dietro di una targa: **il marchio e basta.**
///
/// Il davanti porta gia' il marchio piccolo, il titolo, la data e com'e'
/// finita: un retro che ripete le stesse cose rende il giro un gesto che non
/// mostra niente. Qui c'e' il metallo nudo con il marchio grande in mezzo —
/// come sul dorso di una carta da collezione, dove non c'e' mai scritto cosa
/// c'e' davanti.
///
/// La luce viene dall'altra parte: gli stessi toni della cornice, girati —
/// chiaro in basso a destra invece che in alto a sinistra. E' il dietro, e va
/// illuminato dal dietro.
class PlaqueBack extends StatelessWidget {
  const PlaqueBack({super.key});

  @override
  Widget build(BuildContext context) {
    return _Laminated(
      child: const DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [Color(0xFFF6DFA0), Color(0xFFC9A227), Color(0xFF8C6D1F)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: CrasyWordmark(
                size: 44,
                alignment: Alignment.center,
                onDark: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
