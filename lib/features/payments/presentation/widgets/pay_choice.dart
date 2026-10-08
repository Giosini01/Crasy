import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:flutter/material.dart';

/// Con cosa si paga il premio di una missione.
enum PayChoice {
  /// Con il saldo che si ha gia' su CRASY.
  portafoglio,

  /// Con la carta, passando da Stripe.
  carta,
}

/// **Come vuoi pagare il premio.**
///
/// Compare solo quando il portafoglio basta davvero a coprire il premio: con un
/// saldo che non basta, due strade di cui una non percorribile sono una domanda
/// inutile e una scelta in meno di quante sembrano.
///
/// ## Perche' si chiede, invece di prendere i soldi e basta
///
/// Il portafoglio e' denaro vinto, e per chi l'ha vinto e' una cosa diversa dal
/// credito di un'app: e' una somma che sta aspettando di uscire sul conto. Un
/// pagamento che se la prende da solo, anche quando e' la cosa comoda, e' un
/// pagamento che qualcuno scopre dopo — ed e' l'unico tipo di sorpresa che con i
/// soldi non si puo' fare.
///
/// ## Dal portafoglio costa meno, e lo si dice
///
/// Con la carta si paga il premio **piu'** le commissioni dell'incasso, perche'
/// del denaro entra davvero e qualcuno se ne prende una parte per farlo entrare.
/// Dal portafoglio quei soldi sono gia' dentro: non c'e' nessun incasso, quindi
/// non c'e' nessuna commissione, e si addebita il premio esatto.
///
/// E' una differenza vera e si scrive, perche' chi legge due cifre diverse per
/// la stessa gara senza una spiegazione pensa a un errore.
Future<PayChoice?> chiediComePagare(
  BuildContext context, {
  required int premioCents,
  required int saldoCents,
  required int conLaCartaCents,
}) {
  return ModalSheet.show<PayChoice>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'COME PAGHI IL PREMIO',
      confirmLabel: 'Annulla',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: _Scelta(
        premioCents: premioCents,
        saldoCents: saldoCents,
        conLaCartaCents: conLaCartaCents,
        onPick: (scelta) => Navigator.of(sheetContext).pop(scelta),
      ),
    ),
  );
}

class _Scelta extends StatelessWidget {
  const _Scelta({
    required this.premioCents,
    required this.saldoCents,
    required this.conLaCartaCents,
    required this.onPick,
  });

  final int premioCents;
  final int saldoCents;
  final int conLaCartaCents;
  final void Function(PayChoice scelta) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Riga(
          titolo: 'Dal portafoglio · ${AppMoney.format(premioCents)}',
          nota:
              'Hai ${AppMoney.format(saldoCents)}. Esce subito e la gara '
              'parte adesso, senza commissioni.',
          forte: true,
          onTap: () => onPick(PayChoice.portafoglio),
        ),
        Divider(color: palette.line, height: 1),
        _Riga(
          titolo: 'Con la carta · ${AppMoney.format(conLaCartaCents)}',
          nota:
              'Il portafoglio resta dov\'è. Costa un po\' di più: '
              'sull\'incasso c\'è una commissione.',
          forte: false,
          onTap: () => onPick(PayChoice.carta),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'In tutti e due i casi il premio resta su CRASY fino alla fine, '
          'poi va a chi vince.',
          style: texts.bodySmall?.copyWith(color: palette.textFaint),
        ),
      ],
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({
    required this.titolo,
    required this.nota,
    required this.forte,
    required this.onTap,
  });

  final String titolo;
  final String nota;

  /// Se e' la strada consigliata: il titolo in rosso invece che in nero.
  final bool forte;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titolo,
              style: texts.titleMedium?.copyWith(
                color: forte ? palette.accent : palette.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              nota,
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
