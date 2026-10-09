import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:crasy/features/payments/presentation/widgets/pay_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lanciare una challenge.
///
/// Cinque cose e nient'altro: **quanto si vince, come si chiama, cosa bisogna
/// fare, dove, per quanto tempo**. Sono gli stessi cinque campi che si leggono
/// nella home, nello stesso ordine — chi compila questo modulo sta scrivendo
/// esattamente quello che gli altri vedranno.
///
/// Chi lancia una challenge **non allega nessuna foto**: la faccia della gara
/// la mettono i partecipanti. Ed e' anche chi paga il premio — CRASY non fa da
/// garante, e la schermata lo dice invece di lasciarlo capire dopo.
class CreateChallengePage extends ConsumerStatefulWidget {
  const CreateChallengePage({this.forFriends = false, super.key});

  /// **Due schermate, non una con un interruttore.**
  ///
  /// Sono la stessa pagina nel codice e due cose diverse per chi le usa, e la
  /// differenza non e' l'ambito: e' il premio. In una si mettono dei soldi e il
  /// minimo e' un euro; nell'altra la scelta e' **gratis oppure almeno un
  /// euro**, senza vie di mezzo — perche' lasciato libero, quel campo si
  /// riempie di dieci centesimi, che non sono un premio ne' uno scherzo e fanno
  /// sembrare piccola tutta l'app.
  ///
  /// Tenerle in un modulo solo avrebbe voluto dire una voce "solo amici" in
  /// fondo a una fila, dove non la sceglie nessuno, e un campo del premio che
  /// cambia regola a seconda di cosa hai toccato tre righe sopra.
  final bool forFriends;

  @override
  ConsumerState<CreateChallengePage> createState() =>
      _CreateChallengePageState();
}

/// Le durate che si possono scegliere, in minuti.
///
/// Il tetto e' **un giorno**, e non e' un limite tecnico: una gara che dura una
/// settimana non ha nessuna urgenza, e l'urgenza e' meta' del motivo per cui
/// uno esce di casa a fare una foto assurda.
///
/// **Il pavimento e' un'ora, e prima non c'era.** C'erano un minuto e cinque
/// minuti, messi per provare l'app quando le gare bisognava vederle nascere e
/// morire in fretta. Erano in cima alla fila, cioe' i primi su cui cade il dito,
/// e una gara da un minuto non e' una gara: nasce, nessuno fa in tempo a
/// vederla, e muore senza partecipanti. Chi la lanciava per sbaglio concludeva
/// che l'app non funziona.
///
/// Erano uno strumento di sviluppo lasciato in mano alla gente, ed e' il tipo di
/// cosa che non si nota finche' qualcuno non la tocca.
const _durations = <(int, String)>[
  (60, '1 ORA'),
  (120, '2 ORE'),
  (180, '3 ORE'),
  (300, '5 ORE'),
  (600, '10 ORE'),
  (1440, '24 ORE'),
];

class _CreateChallengePageState extends ConsumerState<CreateChallengePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _brief = TextEditingController();

  /// Quale consiglio tocca a questa volta.
  ///
  /// **Si sceglie all'apertura e poi non cambia piu'.** Preso a ogni ridisegno
  /// cambierebbe mentre si scrive — a ogni lettera battuta nel campo sopra — e
  /// una riga che si riscrive da sola sotto le dita e' la cosa piu' fastidiosa
  /// che una schermata possa fare: si smette di scrivere per leggerla, ogni
  /// volta.
  final int _semeDelConsiglio = DateTime.now().millisecondsSinceEpoch;

  final _prize = TextEditingController();

  /// Serve solo a sapere **quando si esce dal campo del premio**.
  ///
  /// E' li' che l'importo si mette in ordine — `88` diventa `88,00` — e non
  /// mentre si scrive: formattando a ogni tasto, il primo `1` diventerebbe
  /// `1,00` e il cursore finirebbe dopo gli zeri, cioe' non si riuscirebbe piu'
  /// a scrivere `10`.
  final _prizeFocus = FocusNode();

  int _minutes = 1440;

  /// Il campo di gara. **Non si sceglie piu': si decide da quale schermata si
  /// e' entrati.** Una gara aperta e' aperta a tutti, una lanciata dalla
  /// schermata degli amici la vedono gli amici.
  late final ChallengeScope _scope = widget.forFriends
      ? ChallengeScope.friends
      : ChallengeScope.global;

  /// Nella gara fra amici: senza premio.
  ///
  /// Parte **acceso**, e il valore di partenza e' il consiglio: fra amici la
  /// sfida vale gia' per conto suo, e chi vuole metterci dei soldi lo sa gia' e
  /// tocca l'altro tasto.
  var _gratis = true;

  /// Quante persone possono partecipare. Zero: senza limite.
  ///
  /// Parte da **dieci**, ed e' il consiglio giusto: con dieci foto si guardano
  /// tutte e il voto vale qualcosa, e un premio diviso per una possibilita' su
  /// dieci resta una scommessa vera.
  var _maxPartecipanti = 10;
  MediaKind _mediaKind = MediaKind.photo;

  /// **Istantanea, salvo scelta contraria.** E' il valore predefinito e non e'
  /// un caso: e' quello che CRASY e'. L'archivio esiste per le gare che
  /// altrimenti non si potrebbero fare — non e' l'alternativa comoda da
  /// prendere per distrazione.
  ChallengeSource _source = ChallengeSource.instant;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prizeFocus.addListener(_ordinaPremio);
  }

  /// Riscrive il premio con i due decimali, quando il campo perde il fuoco.
  ///
  /// Non tocca niente se quello che c'e' scritto non e' un importo: il campo
  /// deve restare com'e' per far leggere l'errore accanto a quello che si e'
  /// battuto davvero.
  void _ordinaPremio() {
    if (_prizeFocus.hasFocus) {
      return;
    }

    final cents = AppMoney.centsFrom(_prize.text);

    if (cents == null) {
      return;
    }

    final ordinato = AppMoney.plain(cents);

    if (_prize.text == ordinato) {
      return;
    }

    _prize.value = TextEditingValue(
      text: ordinato,
      // Il cursore va in fondo. Senza dirlo resta dov'era, e su un testo
      // diventato piu' lungo Flutter lo rimette all'inizio: si torna nel campo
      // e si scrive prima della cifra invece che dopo.
      selection: TextSelection.collapsed(offset: ordinato.length),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _brief.dispose();
    _prize.dispose();
    _prizeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final creating = ref.watch(createChallengeControllerProvider).isLoading;

    // **Mentre si paga, lo schermo e' coperto.**
    //
    // Non e' solo per dire che sta lavorando: e' per togliere i tasti da sotto
    // le dita. Fra il tocco e il foglio di Stripe passano dei secondi, e in
    // quei secondi un bottone ancora premibile significa due pagamenti aperti
    // per la stessa gara.
    return VeloDiAttesa(
      acceso: _passo != null && _error == null,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.forFriends ? 'Sfida i tuoi amici' : 'Crea'),
        ),
        body: Stack(
          children: [
            AppBackground(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  children: [
                    DisplayTitle(
                      widget.forFriends
                          ? 'SFIDA\nI TUOI AMICI'
                          : 'DAI UN ORDINE\nAL MONDO',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Chi apre questa schermata deve capire in tre secondi che qui
                    // non si racconta una cosa propria: **si dice agli altri cosa
                    // fare**. E' il rovescio esatto della home, dove uno riceve un
                    // ordine e decide se eseguirlo. Se le due schermate si
                    // somigliassero, nessuno capirebbe di essere passato dall'altra
                    // parte del tavolo.
                    if (widget.forFriends)
                      const HighlightedText(
                        'La vedono soltanto i tuoi amici. Nessun altro, nemmeno con '
                        'il link.',
                        highlight: 'soltanto i tuoi amici',
                      )
                    else
                      const HighlightedText(
                        'Metti un premio e decidi tu cosa deve fare la gente. Chi lo '
                        'fa meglio si prende i soldi.',
                        highlight: 'decidi tu cosa deve fare la gente',
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    // **Fra amici la scelta e' secca: gratis, oppure da un euro in
                    // su.** Non c'e' una terza strada, e non e' una dimenticanza:
                    // lasciato libero, quel campo si riempie di dieci centesimi — che
                    // non sono un premio ne' uno scherzo, e fanno sembrare piccola
                    // tutta l'app. Due tasti tolgono la domanda invece di lasciarla
                    // aperta.
                    if (widget.forFriends) ...[
                      _SectionLabel('Il premio'),
                      Row(
                        children: [
                          Expanded(
                            child: _Choice(
                              label: 'GRATIS',
                              selected: _gratis,
                              onTap: () => setState(() => _gratis = true),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _Choice(
                              label: 'CON PREMIO',
                              selected: !_gratis,
                              onTap: () => setState(() => _gratis = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _gratis
                            ? 'Si gioca per la figurina e per il gusto di farlo.'
                            : 'Da un euro in su. I soldi li dai tu a chi vince.',
                        style: texts.bodySmall?.copyWith(
                          color: palette.textFaint,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (!widget.forFriends || !_gratis)
                      _Field(
                        label: 'Premio in euro',
                        controller: _prize,
                        focusNode: _prizeFocus,
                        // Il suggerimento porta i centesimi apposta: e' l'unico posto
                        // in cui il campo dice di accettarli. Un `500` li' dentro
                        // lascerebbe credere che si scrivano solo cifre tonde.
                        hint: '10,50',
                        // `decimal: true` e' quello che mette il tasto della virgola
                        // sulla tastiera dell'iPhone. Senza, i centesimi si possono
                        // accettare quanto si vuole: non c'e' modo di digitarli.
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        // Passano cifre, virgola e punto. Il punto perche' la tastiera
                        // di un telefono in inglese offre quello, e un campo che
                        // rifiuta il tasto che la tastiera stessa suggerisce sembra
                        // rotto. A dire se quello che ne esce e' un importo valido ci
                        // pensa il controllo, non il filtro: qui si decide solo cosa
                        // si puo' battere.
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        // **Il minimo e' un euro anche qui dentro.** Lo zero non si
                        // scrive: si sceglie con il tasto GRATIS. Cosi' non esiste la
                        // via di mezzo — dieci centesimi — che era il motivo per cui
                        // queste due schermate sono diventate due.
                        validator: ChallengeDraftValidators.validatePrize,
                      ),
                    // **La regola si legge prima, non dopo.** Un minimo che si scopre
                    // premendo "pubblica" e' un errore rosso preso in faccia dopo
                    // aver riempito tutto il resto; scritto qui e' un'informazione.
                    if (!widget.forFriends || !_gratis)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          'Almeno ${AppMoney.format(ChallengeDraftValidators.prizeMinCents)}.',
                          style: context.texts.bodySmall?.copyWith(
                            color: context.palette.textFaint,
                          ),
                        ),
                      ),
                    _Field(
                      label: 'Come si chiama',
                      controller: _title,
                      // Il suggerimento e' nella stessa lingua e nello stesso tono
                      // della consegna qui sotto: due esempi che si leggono di fila
                      // devono sembrare scritti dalla stessa persona.
                      hint: 'Foto con uno sconosciuto',
                      maxLength: ChallengeDraftValidators.titleMaxLength,
                      validator: ChallengeDraftValidators.validateTitle,
                    ),
                    _Field(
                      label: 'Cosa devono fare',
                      controller: _brief,
                      hint:
                          'Fermate uno sconosciuto per strada e fatevi fotografare '
                          'insieme.',
                      maxLines: 3,
                      maxLength: ChallengeDraftValidators.briefMaxLength,
                      validator: ChallengeDraftValidators.validateBrief,
                    ),
                    _Consiglio(seme: _semeDelConsiglio),
                    const SizedBox(height: AppSpacing.sm),
                    _SectionLabel('Cosa devono mandare'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final kind in MediaKind.values)
                          _Choice(
                            label: kind.label,
                            selected: _mediaKind == kind,
                            onTap: () => setState(() => _mediaKind = kind),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // **Da dove lo devono prendere.**
                    //
                    // E' la seconda regola della gara, dopo cosa mandare, e la decide
                    // chi mette i soldi. Non e' una comodita' lasciata al
                    // partecipante: lasciandola a lui, davanti a "scatta adesso"
                    // oppure "prendi quella che hai gia'" vincerebbe sempre la
                    // seconda, e la gara istantanea morirebbe da sola. Vedi
                    // `ChallengeSource`.
                    _SectionLabel('Da dove lo prendono'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final source in ChallengeSource.values)
                          _Choice(
                            label: source.label,
                            selected: _source == source,
                            onTap: () => setState(() => _source = source),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_comeSiPartecipa(), style: texts.bodySmall),
                    const SizedBox(height: AppSpacing.lg),
                    const SizedBox(height: AppSpacing.lg),
                    // **Quanti possono entrare.** E' la scelta che decide se la gara
                    // e' un gioco o una folla: con cinquecento foto nessuno le guarda
                    // tutte, si vota fra le prime che capitano, e vince la posizione
                    // nella lista invece di quello che uno ha fatto.
                    _SectionLabel('Quanti possono partecipare'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final quanti in Challenge.participantCaps)
                          _Choice(
                            label: '$quanti',
                            selected: _maxPartecipanti == quanti,
                            onTap: () =>
                                setState(() => _maxPartecipanti = quanti),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        'Una possibilità su $_maxPartecipanti. Quando i posti '
                        'finiscono, non si entra più.',
                        style: texts.bodySmall?.copyWith(
                          color: palette.textFaint,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('Quanto dura'),
                    // **Solo caselle, niente campo da riempire.**
                    //
                    // La durata non e' un numero qualunque: e' una delle tre cose che
                    // decidono se una gara funziona. Un campo libero fa scrivere 37
                    // minuti — che non e' sbagliato, e' solo una scelta che nessuno
                    // aveva motivo di fare — e costringe a battere dei numeri su una
                    // tastiera per una cosa che si sceglie in un colpo d'occhio.
                    //
                    // Le prime due sono per provare: un minuto e' il tempo che ci
                    // vuole a vedere il giro intero — si lancia, si partecipa, si
                    // vota, si chiude — senza restare seduti ad aspettare.
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final choice in _durations)
                          _Choice(
                            label: choice.$2,
                            selected: _minutes == choice.$1,
                            onTap: () => setState(() => _minutes = choice.$1),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      InlineBanner(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    // Il conto, prima del bottone.
                    //
                    // Chi sta per pagare deve vedere **la cifra esatta che gli
                    // uscira' dalla carta** mentre ha ancora il dito lontano dal
                    // bottone. Una schermata che dice "500" e una carta addebitata di
                    // "507,75" e' il tipo di sorpresa che, in un'app che maneggia
                    // soldi, non si recupera piu'.
                    if (paymentsEnabled) _PaymentSummary(prize: _prize),
                    CrasyButton(
                      label: paymentsEnabled
                          ? 'Paga e lancia la challenge'
                          : 'Lancia la challenge',
                      loading: creating,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Detto prima, non dopo. E' l'unica riga di questa schermata che
                    // parla di soldi veri, e chi la legge deve poterci ripensare
                    // mentre ha ancora il dito lontano dal bottone.
                    Text(
                      paymentsEnabled
                          // **Detto prima di pagare, non dopo.**
                          //
                          // Sono le due cose che uno scopre nel momento sbagliato se
                          // non gliele dici adesso: che cancellando **non torna
                          // tutto** — restano fuori le spese di pagamento, gia'
                          // uscite — e che i soldi non rientrano in tempo reale.
                          // Chi lo legge qui non ha sorprese; chi lo scopre dopo
                          // pensa di essere stato fregato, ed e' la stessa cosa
                          // vista da due momenti diversi.
                          ? 'Il premio lo trattiene CRASY fino alla fine della '
                                'challenge, poi lo gira a chi vince. Se non '
                                'partecipa nessuno ti torna indietro intero. Se '
                                'invece la cancelli tu, ti torna il premio ma non '
                                'le spese di pagamento — e la banca ci mette 5-10 '
                                'giorni a rimettertelo sulla carta.'
                          : 'Il premio lo paghi tu. CRASY non fa da garante e non '
                                'trattiene i soldi: mettine uno che puoi davvero '
                                'dare.',
                      style: texts.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cosa succedera' a chi partecipa, detto a chi sta lanciando la gara.
  ///
  /// **Le quattro combinazioni scritte per esteso, non due frasi incastrate.**
  /// Chi mette dei soldi ha diritto di sapere esattamente cosa gli arrivera' —
  /// e la differenza fra "registrato sul momento" e "un video che ha gia'" e'
  /// tutta la differenza fra due gare diverse.
  String _comeSiPartecipa() {
    final video = _mediaKind.isVideo;

    if (_source.isArchive) {
      return video
          ? "Tutti mandano un video che hanno già sul telefono. La fotocamera "
                "non si apre, e non c'è un limite di durata."
          : "Tutti mandano una foto che hanno già sul telefono. La fotocamera "
                "non si apre.";
    }

    return video
        ? 'Tutti mandano un video registrato sul momento, al massimo '
              '${MediaKind.maxVideoDuration.inSeconds} secondi. La galleria non '
              'si apre.'
        : 'Tutti mandano una foto scattata sul momento. La galleria non si '
              'apre.';
  }

  /// La missione gia' scritta, in attesa di essere pagata.
  ///
  /// **Esiste per non riscriverla a ogni tentativo.** Una missione si scrive
  /// prima e si paga dopo: se il pagamento non parte, quella che e' stata
  /// scritta resta li' — e infatti il messaggio d'errore lo dice, "la
  /// challenge e' salvata". Premendo di nuovo pero' si ripartiva da capo, e
  /// ogni tocco lasciava dietro di se' una missione mai pagata e un pagamento
  /// mai concluso. Undici tentativi, undici missioni fantasma.
  ///
  /// Nessuno ci rimetteva dei soldi — un pagamento creato e mai confermato non
  /// addebita niente — ma il database si riempiva di copie della stessa cosa,
  /// e chi provava non lo vedeva nemmeno, perche' una missione non pagata non
  /// si vede.
  String? _daPagare;

  /// A che punto e' il pagamento, mentre si aspetta.
  String? _passo;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _error = null;
      _passo = null;
    });

    // Il controllo del modulo e' appena passato, quindi qui c'e' un importo
    // valido. Lo zero di ripiego non serve a coprire un caso vero: serve a non
    // avere un `!` su un campo di testo. Scelto GRATIS, il campo del premio non
    // e' nemmeno a schermo: si manda zero senza guardare cosa c'era scritto.
    final prizeCents = widget.forFriends && _gratis
        ? 0
        : AppMoney.centsFrom(_prize.text) ?? 0;

    // Si riprova a pagare **quella di prima**, non se ne scrive un'altra.
    final challengeId =
        _daPagare ??
        await ref
            .read(createChallengeControllerProvider.notifier)
            .create(
              title: _title.text,
              brief: _brief.text,
              prizeCents: prizeCents,
              scope: _scope,
              maxParticipants: _maxPartecipanti,
              mediaKind: _mediaKind,
              source: _source,
              // **Nessuna gara nasce piu' legata a un posto.** Il campo c'era e
              // non lo compilava quasi nessuno: una gara e' una consegna — *fai
              // questo* — e dov'e' chi la fa non cambia niente a chi guarda la
              // foto. Le gare vecchie con dentro una citta' restano come sono.
              place: '',
              minutes: _minutes,
            );

    if (!mounted) {
      return;
    }

    if (challengeId == null) {
      final error = ref.read(createChallengeControllerProvider).error;

      setState(() {
        _error = error == null
            ? 'Non siamo riusciti a lanciarla. Riprova.'
            : ErrorMessageMapper.map(error);
      });

      return;
    }

    // Da qui in poi la missione esiste. Se il pagamento non riesce, e' questa
    // che si riprova a pagare.
    _daPagare = challengeId;

    // A pagamenti accesi la challenge **non e' ancora nata**: e' scritta ma non
    // pagata, e finche' non lo e' non la vede nessuno, nemmeno chi l'ha
    // scritta. Si passa dalla pagina di pagamento di Stripe e si torna con la
    // challenge viva.
    // **Senza soldi in palio non c'e' niente da pagare.** Una missione GRATIS
    // fra amici e' visibile da subito, e mandarla a Stripe con zero euro
    // voleva dire un rifiuto del server e una gara bloccata a meta'.
    if (paymentsEnabled && prizeCents > 0) {
      // **Se i soldi ce li hai gia' su CRASY, si puo' pagare con quelli.**
      //
      // La cosa piu' naturale da fare con un premio vinto e' rimetterlo in
      // gioco, e finora per farlo bisognava prelevarlo, aspettare giorni e
      // ripagare con la carta. Per un euro.
      //
      // Si chiede, non si prende: il portafoglio e' denaro che sta aspettando
      // di uscire sul conto, e un pagamento che se lo prende da solo e' una
      // sorpresa — l'unico tipo di sorpresa che con i soldi non si fa.
      //
      // La domanda compare solo se il saldo copre davvero il premio: due strade
      // di cui una impraticabile sono una scelta in meno di quante sembrano.
      final saldo = ref.read(walletBalanceProvider);

      if (saldo >= prizeCents) {
        final scelta = await chiediComePagare(
          context,
          premioCents: prizeCents,
          saldoCents: saldo,
          conLaCartaCents: PrizeLedger.chargeCents(prizeCents),
        );

        if (!mounted) {
          return;
        }

        // Chiuso il foglio senza scegliere: la gara resta salvata e non pagata,
        // com'era un attimo fa. Non e' un errore e non si dice niente.
        if (scelta == null) {
          return;
        }

        if (scelta == PayChoice.portafoglio) {
          final esito = await ref
              .read(paymentsServiceProvider)
              .payChallengeFromWallet(challengeId);

          if (!mounted) {
            return;
          }

          if (!esito.pagata) {
            setState(() {
              _error = esito.saldoBasso
                  // Fra l'apertura del foglio e il tocco puo' essere partito un
                  // prelievo: il saldo di un attimo fa non e' una promessa.
                  ? "Il portafoglio non basta più. La challenge è "
                        "salvata: riprova, o paga con la carta."
                  : 'Non siamo riusciti a pagare dal portafoglio. La challenge '
                        'è salvata: riprova fra poco.';
            });

            return;
          }

          // **Qui si atterra sulla gara, al contrario che con la carta.**
          //
          // Con Stripe si torna indietro, perche' la gara non e' visibile
          // finche' il pagamento non arriva e mandare qualcuno su una pagina
          // vuota dopo avergli chiesto dei soldi e' il modo migliore di fargli
          // credere di essere stato truffato. Dal portafoglio il premio e' gia'
          // dentro e la gara e' gia' aperta: e' la prova che e' andata bene.
          context.pushReplacement(AppRoutes.challengeDetailOf(challengeId));

          return;
        }
      }

      // **Un errore del server va detto, non inghiottito.** Senza questo
      // `try` un rifiuto di `startChallengePayment` si perdeva per strada: il
      // bottone tornava com'era, Stripe non si apriva e sullo schermo non
      // compariva niente — e da fuori sembrava un link che non si apre. Il
      // codice resta scritto nel messaggio perche' e' l'unica cosa che dice,
      // da un telefono su TestFlight, cosa guardare nei log.
      final bool opened;

      try {
        opened = await ref
            .read(paymentsServiceProvider)
            .payChallenge(
              challengeId,
              // Sul sito, dopo Stripe, si torna alla schermata da cui si era
              // aperto il modulo: la scheda delle challenge, o l'attivita'
              // degli amici per le missioni di party. Sono le sole due porte
              // da cui si entra qui.
              returnRoute: widget.forFriends
                  ? AppRoutes.friendsActivity
                  : AppRoutes.challenges,
              // **Si scrive a schermo a che punto e'.**
              //
              // Fra il tocco e il foglio di Stripe ci sono tre passi, e finche'
              // non se ne vedeva nessuno un blocco in mezzo era
              // indistinguibile da un bottone morto: niente foglio, niente
              // errore, niente da raccontare. Adesso l'ultimo passo riuscito
              // resta scritto, e dice da dove ricominciare a guardare.
              passo: (passo) {
                if (mounted) {
                  setState(() => _passo = passo);
                }
              },
            );
      } on FirebaseFunctionsException catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _error =
              'Non siamo riusciti ad aprire il pagamento (${error.code}). '
              'La challenge è salvata: riprova fra poco.';
        });

        return;
      } catch (error) {
        if (!mounted) {
          return;
        }

        // **Anche qui il motivo, non solo il fatto.** Il foglio di Stripe
        // fallisce per cose che si possono leggere — una carta rifiutata, una
        // configurazione sbagliata — e nasconderle tutte dietro la stessa
        // frase vuol dire un'app che non sa mai dire cos'e' andato storto,
        // ne' a chi la usa ne' a chi la ripara.
        setState(() {
          _error =
              'Non siamo riusciti ad aprire il pagamento: $error. '
              'La challenge è salvata: riprova fra poco.';
        });

        return;
      }

      if (!mounted) {
        return;
      }

      if (!opened) {
        setState(() {
          _error =
              'Non siamo riusciti ad aprire il pagamento. La challenge è '
              'salvata: riprova fra poco.';
        });

        return;
      }

      // Non si atterra sulla challenge: non e' visibile finche' Stripe non ci
      // dice che i soldi sono arrivati, e mandare qualcuno su una pagina vuota
      // subito dopo avergli chiesto dei soldi e' il modo migliore di fargli
      // credere di essere stato truffato.
      context.pop();

      return;
    }

    // Si atterra sulla challenge appena nata, non sulla home: e' la prova che
    // e' andata a buon fine, e da li' si condivide.
    context.pushReplacement(AppRoutes.challengeDetailOf(challengeId));
  }
}

/// Il conto esatto, sotto il modulo e sopra il bottone.
///
/// Si aggiorna mentre si digita — da qui il `ValueListenableBuilder`, invece di
/// un `setState` a ogni tasto — perche' la domanda "quanto mi costa davvero?"
/// arriva **mentre** si sceglie la cifra, non dopo averla scelta.
///
/// Le tre righe dicono tre cose diverse e tutte e tre servono: quanto esce
/// dalla carta, quanto arriva a chi vince, quanto tiene CRASY. La terza in
/// particolare: una piattaforma che non dice quanto si prende la fa sembrare
/// piu' di quanto sia.
class _PaymentSummary extends ConsumerWidget {
  const _PaymentSummary({required this.prize});

  final TextEditingController prize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final saldo = ref.watch(walletBalanceProvider);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: prize,
      builder: (context, value, child) {
        final cents = AppMoney.centsFrom(value.text) ?? 0;

        // Finche' non c'e' un importo valido non c'e' niente da riepilogare, e
        // un riepilogo di zeri mentre si sta ancora scrivendo la cifra e' un
        // lampeggio, non un'informazione.
        if (cents <= 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            children: [
              Divider(color: palette.line),
              const SizedBox(height: AppSpacing.sm),
              _SummaryRow(
                label: 'Paghi ora',
                value: AppMoney.format(PrizeLedger.chargeCents(cents)),
                strong: true,
              ),
              _SummaryRow(
                label: 'Va a chi vince',
                value: AppMoney.format(PrizeLedger.payoutCents(cents)),
              ),
              _SummaryRow(
                label: 'Trattiene CRASY',
                value: AppMoney.format(PrizeLedger.commissionCents(cents)),
              ),
              _SummaryRow(
                label: 'Commissioni banca',
                value: AppMoney.format(PrizeLedger.processingFeeCents(cents)),
              ),
              // **Il portafoglio si dice qui, non al momento di pagare.**
              //
              // La scelta fra carta e portafoglio compare dopo, quando si
              // preme il tasto — ed era l'unico posto in cui compariva. Chi non
              // arriva in fondo non sa nemmeno che si puo' fare, e chi ci
              // arriva se la trova addosso senza averci pensato. Il momento in
              // cui serve saperlo e' **mentre si sceglie la cifra**: e' li' che
              // uno decide quanto mettere, e sapere di avere un euro gia'
              // dentro cambia la decisione.
              //
              // Compare solo se il saldo copre il premio, come il foglio dopo:
              // scriverlo quando non basta vorrebbe dire annunciare una strada
              // che poi non si apre.
              if (saldo >= cents) ...[
                const SizedBox(height: AppSpacing.xs),
                _SummaryRow(
                  label: 'Oppure dal portafoglio',
                  value: AppMoney.format(cents),
                  accent: true,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hai ${AppMoney.format(saldo)}: pagando da lì non ci sono '
                    'commissioni, e te lo chiediamo prima di toccarli.',
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Divider(color: palette.line),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool strong;

  /// La riga in rosso: la usa il portafoglio, che non e' un costo in piu' ma
  /// **un'altra strada** per lo stesso. In grigio come le altre si leggerebbe
  /// come una quarta voce del conto, cioe' come altri soldi da tirare fuori.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final style = accent
        ? texts.titleMedium?.copyWith(color: palette.accent)
        : strong
        ? texts.titleMedium
        : texts.bodySmall?.copyWith(color: palette.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: context.palette.textFaint,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        // **Il tasto in basso a destra chiude la tastiera, non va a capo.**
        //
        // Su un campo a piu' righe Flutter mette l'a-capo, che e' la scelta
        // giusta per un editor di testo e sbagliata qui: la consegna di una
        // challenge sta in tre righe e nessuno ci va a capo apposta, mentre
        // tutti hanno bisogno di **togliere di mezzo la tastiera** — che qui
        // copre meta' modulo e il bottone per pubblicare.
        //
        // Su iOS il tasto diventa "Fine". Un a-capo non si puo' piu' scrivere,
        // ed e' esattamente cio' che si voleva.
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          hintText: hint,
        ),
      ),
    );
  }
}

/// Una scelta fra poche: testo, filetto, e il rosso solo su quella attiva.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.accentTint : null,
          border: Border.all(color: selected ? palette.accent : palette.line),
        ),
        child: Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: selected ? palette.accent : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// **Un consiglio sotto la consegna, uno solo.**
///
/// Chi lancia la prima missione non sa cosa rende una missione bella, e lo
/// scopre dopo: quando nessuno partecipa. I suggerimenti dentro i campi mostrano
/// **un esempio**; questo dice **la regola** che quell'esempio segue — sono due
/// cose diverse, e la seconda e' quella che si porta via.
///
/// ## Perche' una riga e non un riquadro
///
/// La tentazione era una scheda con l'icona della lampadina e tre punti
/// elenco. Sarebbe stata la cosa piu' grossa della schermata, sopra il campo
/// piu' importante, e l'avrebbero letta una volta e saltata per sempre — che e'
/// il destino di qualunque aiuto che si fa notare piu' del lavoro.
///
/// Una riga grigia sotto il campo si legge mentre si pensa a cosa scrivere,
/// cioe' nel solo momento in cui serve. E non va chiusa: una cosa che non
/// ingombra non ha bisogno di una crocetta.
///
/// ## Cambia a ogni missione
///
/// Sono sei, e ne compare una per volta, scelta all'apertura. Mostrarle tutte
/// vorrebbe dire un muro di testo che non legge nessuno; mostrare sempre la
/// stessa vorrebbe dire che dalla seconda missione in poi e' arredamento.
/// Cosi' invece chi lancia la quinta missione ha letto cinque cose diverse,
/// senza che nessuna gli abbia mai chiesto attenzione.
class _Consiglio extends StatelessWidget {
  const _Consiglio({required this.seme});

  final int seme;

  /// **Sei, e dicono tutte una cosa sola ciascuna.**
  ///
  /// Nessuna e' un complimento all'app o un invito generico a fare bene: ogni
  /// riga contiene una decisione che chi scrive la consegna deve prendere
  /// adesso — quanto essere precisi, dove si fa, quanto tempo dare.
  static const _consigli = [
    "Una consegna precisa riempie la gara. \"Una foto buffa\" non si sa come "
        "farla; \"fatti fotografare mentre tocchi un cane che non conosci\" sì.",
    "Chiedi una cosa che si può fare adesso, da dove si è. Se serve uscire, "
        "organizzarsi o aspettare domani, quasi nessuno ci arriva.",
    "Dai abbastanza tempo. Un'ora prende solo chi ha il telefono in mano in "
        "quel momento; un giorno prende tutti gli altri.",
    "Non chiedere due cose insieme. \"Vestiti di rosso e balla\" diventa metà "
        "foto in rosso e metà balli: non si possono più confrontare.",
    "Il titolo si legge per primo, e spesso da solo. Che si capisca da lì "
        "cosa c'è da fare, senza aprire.",
    "Le cose un po' imbarazzanti battono quelle difficili: chi guarda vuole "
        "vedere qualcuno che ci ha provato, non qualcuno che è bravo.",
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        _consigli[seme.abs() % _consigli.length],
        style: context.texts.bodySmall?.copyWith(color: palette.textFaint),
      ),
    );
  }
}
