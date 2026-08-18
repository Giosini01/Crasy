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
  const CreateChallengePage({super.key});

  @override
  ConsumerState<CreateChallengePage> createState() =>
      _CreateChallengePageState();
}

class _CreateChallengePageState extends ConsumerState<CreateChallengePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _brief = TextEditingController();
  final _prize = TextEditingController();
  final _place = TextEditingController();
  final _hours = TextEditingController(text: '24');

  ChallengeScope _scope = ChallengeScope.global;
  MediaKind _mediaKind = MediaKind.photo;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _brief.dispose();
    _prize.dispose();
    _place.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final creating = ref.watch(createChallengeControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Crea')),
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
              const DisplayTitle('DAI UN ORDINE\nAL MONDO'),
              const SizedBox(height: AppSpacing.sm),
              // Chi apre questa schermata deve capire in tre secondi che qui
              // non si racconta una cosa propria: **si dice agli altri cosa
              // fare**. E' il rovescio esatto della home, dove uno riceve un
              // ordine e decide se eseguirlo. Se le due schermate si
              // somigliassero, nessuno capirebbe di essere passato dall'altra
              // parte del tavolo.
              const HighlightedText(
                'Metti un premio e decidi tu cosa deve fare la gente. Chi lo '
                'fa meglio si prende i soldi.',
                highlight: 'decidi tu cosa deve fare la gente',
              ),
              const SizedBox(height: AppSpacing.xl),
              _Field(
                label: 'Premio in euro',
                controller: _prize,
                hint: '500',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: ChallengeDraftValidators.validatePrize,
              ),
              _Field(
                label: 'Titolo',
                controller: _title,
                hint: 'Do something crazy',
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
              _SectionLabel('Dove'),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final scope in ChallengeScope.values)
                    if (scope != ChallengeScope.private)
                      _Choice(
                        label: scope.defaultLabel,
                        selected: _scope == scope,
                        onTap: () => setState(() => _scope = scope),
                      ),
                ],
              ),
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
              _Field(
                label: 'Quanto dura — ore (max 24)',
                controller: _hours,
                hint: '24',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                validator: ChallengeDraftValidators.validateHours,
              ),
              // Le scorciatoie riempiono il campo invece di sostituirlo: il
              // valore resta uno solo e sempre visibile, e chi vuole 7 ore le
              // scrive senza cercare una voce che non c'e'.
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final hours in const [1, 3, 6, 12, 24])
                    _Choice(
                      label: '${hours}H',
                      selected: _hours.text == '$hours',
                      onTap: () => setState(() {
                        _hours.text = '$hours';
                      }),
                    ),
                ],
              ),
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
          prizeEuro: int.parse(_prize.text.trim()),
          scope: _scope,
          mediaKind: _mediaKind,
          place: _place.text,
          hours: int.parse(_hours.text.trim()),
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
        final euro = int.tryParse(value.text.trim()) ?? 0;

        if (euro <= 0) {
          return const SizedBox.shrink();
        }

        final cents = euro * 100;

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
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
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
