import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
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
/// Le prime due sono per provare e spariranno; le altre sono il prodotto. Il
/// tetto e' **un giorno**, e non e' un limite tecnico: una gara che dura una
/// settimana non ha nessuna urgenza, e l'urgenza e' meta' del motivo per cui
/// uno esce di casa a fare una foto assurda.
const _durations = <(int, String)>[
  (1, '1 MIN'),
  (5, '5 MIN'),
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

  final _prize = TextEditingController();

  /// Serve solo a sapere **quando si esce dal campo del premio**.
  ///
  /// E' li' che l'importo si mette in ordine — `88` diventa `88,00` — e non
  /// mentre si scrive: formattando a ogni tasto, il primo `1` diventerebbe
  /// `1,00` e il cursore finirebbe dopo gli zeri, cioe' non si riuscirebbe piu'
  /// a scrivere `10`.
  final _prizeFocus = FocusNode();

  final _place = TextEditingController();
  int _minutes = 1440;

  late ChallengeScope _scope = widget.forFriends
      ? ChallengeScope.friends
      : ChallengeScope.global;

  /// Nella gara fra amici: senza premio.
  ///
  /// Parte **acceso**, e il valore di partenza e' il consiglio: fra amici la
  /// sfida vale gia' per conto suo, e chi vuole metterci dei soldi lo sa gia' e
  /// tocca l'altro tasto.
  var _gratis = true;
  MediaKind _mediaKind = MediaKind.photo;
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
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final creating = ref.watch(createChallengeControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forFriends ? 'Sfida i tuoi amici' : 'Crea'),
      ),
      body: AppBackground(
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
                  style: texts.bodySmall?.copyWith(color: palette.textFaint),
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
              const SizedBox(height: AppSpacing.xs),
              Text(
                _mediaKind.isVideo
                    ? 'Tutti mandano un video, registrato sul momento, al '
                          'massimo ${MediaKind.maxVideoDuration.inSeconds} '
                          'secondi.'
                    : 'Tutti mandano una foto, scattata sul momento.',
                style: texts.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Il campo di gara si sceglie solo nelle gare aperte a tutti: in
              // quella fra amici e' gia' deciso dal titolo della schermata, e
              // una fila di scelte in cui una sola e' valida non e' una scelta.
              if (!widget.forFriends) ...[
                _SectionLabel('Dove'),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final scope in ChallengeScope.values)
                      // "Solo amici" non sta qui: ha una schermata sua, con la
                      // sua regola sul premio. Lasciarla anche in questa fila
                      // vorrebbe dire due strade per la stessa cosa, e una
                      // delle due con le regole sbagliate.
                      if (scope != ChallengeScope.private &&
                          scope != ChallengeScope.friends)
                        _Choice(
                          label: scope.defaultLabel,
                          selected: _scope == scope,
                          onTap: () => setState(() => _scope = scope),
                        ),
                  ],
                ),
              ],
              // **Cosa vuol dire "solo amici", detto prima di scegliere.**
              //
              // E' l'unica voce di questa fila che cambia *chi vede la gara* e
              // non *dove si gioca*, e la differenza non si indovina da una
              // parola sola. Chi la sceglie deve sapere due cose: che fuori dai
              // suoi amici non la vede nessuno, e che l'elenco e' quello di
              // adesso.
              if (_scope == ChallengeScope.local) ...[
                const SizedBox(height: AppSpacing.md),
                _Field(
                  label: 'Citta\'',
                  controller: _place,
                  hint: 'NAPOLI',
                  validator: (value) =>
                      ChallengeDraftValidators.validatePlace(_scope, value),
                ),
              ],
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
                    ? 'Il premio lo trattiene CRASY fino alla fine della '
                          'challenge, poi lo gira a chi vince. Se non partecipa '
                          'nessuno, ti torna indietro intero.'
                    : 'Il premio lo paghi tu. CRASY non fa da garante e non '
                          'trattiene i soldi: mettine uno che puoi davvero '
                          'dare.',
                style: texts.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _error = null);

    final challengeId = await ref
        .read(createChallengeControllerProvider.notifier)
        .create(
          title: _title.text,
          brief: _brief.text,
          // Il controllo del modulo e' appena passato, quindi qui c'e' un
          // importo valido. Lo zero di ripiego non serve a coprire un caso
          // vero: serve a non avere un `!` su un campo di testo, che il giorno
          // che qualcuno tocca il controllo diventa una schermata che si
          // chiude da sola.
          // Scelto GRATIS, il campo del premio non e' nemmeno a schermo: si
          // manda zero senza guardare cosa c'era scritto prima di cambiare
          // idea.
          prizeCents: widget.forFriends && _gratis
              ? 0
              : AppMoney.centsFrom(_prize.text) ?? 0,
          scope: _scope,
          mediaKind: _mediaKind,
          place: _place.text,
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

    // A pagamenti accesi la challenge **non e' ancora nata**: e' scritta ma non
    // pagata, e finche' non lo e' non la vede nessuno, nemmeno chi l'ha
    // scritta. Si passa dalla pagina di pagamento di Stripe e si torna con la
    // challenge viva.
    if (paymentsEnabled) {
      final opened = await ref
          .read(paymentsServiceProvider)
          .payChallenge(challengeId);

      if (!mounted) {
        return;
      }

      if (!opened) {
        setState(() {
          _error =
              'Non siamo riusciti ad aprire il pagamento. La challenge e\' '
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
class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.prize});

  final TextEditingController prize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final style = strong
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
