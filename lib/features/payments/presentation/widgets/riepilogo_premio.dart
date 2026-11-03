import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Il conto esatto di un premio, sopra il tasto che lo fa pagare.**
///
/// Chi sta per pagare deve vedere la cifra che gli uscira' dalla carta mentre ha
/// ancora il dito lontano dal bottone. Sta qui perche' si paga in due posti: nel
/// modulo, e nella pagina di una missione appena approvata. Due conti scritti a
/// parte finirebbero per dire due cifre diverse.
class RiepilogoPremio extends ConsumerWidget {
  const RiepilogoPremio({
    required this.cents,
    this.primaRiga = 'Paghi ora',
    super.key,
  });

  final int cents;

  /// **Nel modulo non si paga ancora.** Prima c'e' il controllo, e se la missione deve
  /// guardarla una persona non parte nessun pagamento: "Paghi ora" sarebbe falso.
  final String primaRiga;

  /// **Detto prima di pagare, non dopo.**
  ///
  /// Sono le due cose che uno scopre nel momento sbagliato se non gliele dici
  /// adesso: che cancellando **non torna tutto** — restano fuori le spese di
  /// pagamento, gia' uscite — e che i soldi non rientrano in tempo reale. Chi lo
  /// legge qui non ha sorprese; chi lo scopre dopo pensa di essere stato fregato,
  /// ed e' la stessa cosa vista da due momenti diversi.
  static const avvertenza =
      'Il premio lo trattiene CRASY fino alla fine della challenge, poi lo gira '
      'a chi vince. Se non partecipa nessuno ti torna indietro intero. Se invece '
      'la cancelli tu, ti torna il premio ma non le spese di pagamento — e la '
      'banca ci mette 5-10 giorni a rimettertelo sulla carta.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final saldo = ref.watch(walletBalanceProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          Divider(color: palette.line),
          const SizedBox(height: AppSpacing.sm),
          _RigaDelConto(
            label: primaRiga,
            value: AppMoney.format(PrizeLedger.chargeCents(cents)),
            strong: true,
          ),
          _RigaDelConto(
            label: 'Va a chi vince',
            value: AppMoney.format(PrizeLedger.payoutCents(cents)),
          ),
          _RigaDelConto(
            label: 'Trattiene CRASY',
            value: AppMoney.format(PrizeLedger.commissionCents(cents)),
          ),
          _RigaDelConto(
            label: 'Commissioni banca',
            value: AppMoney.format(PrizeLedger.processingFeeCents(cents)),
          ),
          _RigaDelConto(
            label: 'Servizio CRASY',
            value: AppMoney.format(PrizeLedger.serviceCents),
          ),
          // **Il portafoglio si dice qui, non al momento di pagare.**
          //
          // La scelta fra carta e portafoglio compare dopo, quando si preme il
          // tasto — ed era l'unico posto in cui compariva. Chi non arriva in
          // fondo non sa nemmeno che si puo' fare, e chi ci arriva se la trova
          // addosso senza averci pensato. Il momento in cui serve saperlo e'
          // **mentre si sceglie la cifra**: e' li' che uno decide quanto mettere,
          // e sapere di avere un euro gia' dentro cambia la decisione.
          //
          // Compare solo se il saldo copre il premio, come il foglio dopo:
          // scriverlo quando non basta vorrebbe dire annunciare una strada che
          // poi non si apre.
          if (saldo >= cents) ...[
            const SizedBox(height: AppSpacing.xs),
            _RigaDelConto(
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
  }
}

class _RigaDelConto extends StatelessWidget {
  const _RigaDelConto({
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
