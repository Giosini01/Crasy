import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/payments/domain/entities/ledger_entry.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Tutti i movimenti: quanto hai pagato, quanto ti e' tornato, quanto hai
/// vinto.**
///
/// ## Perche' non bastava il portafoglio
///
/// Il portafoglio mostra il saldo e le righe che lo muovono. Ma una missione
/// pagata **con la carta** non lo muove: quei soldi vanno dalla carta a Stripe
/// e nel portafoglio non compaiono mai. Risultato: undici pagamenti, alcuni
/// rimborsati in parte, che esistevano solo sulla dashboard di Stripe — cioe'
/// visibili a noi e non a chi li aveva fatti.
///
/// E nemmeno le gare potevano raccontarli: annullandone una si cancella, e con
/// lei la prova di cosa era stato pagato.
///
/// Qui c'e' tutto, in ordine di tempo, con scritto **dove** sono passati i
/// soldi: carta, portafoglio, conto corrente. E' la domanda che la gente fa per
/// prima quando guarda un movimento, e un elenco che non risponde serve a poco.
///
/// ## Una cosa che questa pagina non fa
///
/// Non si puo' toccare niente. Nessun tasto per correggere, nessuno per
/// nascondere una riga: il registro e' scritto dal server e nemmeno il
/// proprietario ci puo' scrivere. Un estratto conto in cui una riga di ieri
/// puo' cambiare oggi non e' un estratto conto.
class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final movimenti = ref.watch(ledgerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Movimenti'),
      ),
      body: AppBackground(
        child: switch (movimenti) {
          null => Center(
            child: CircularProgressIndicator(color: palette.accent),
          ),
          [] => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: EmptyState(
              title: 'Ancora nessun movimento',
              message:
                  'Qui finisce tutto quello che riguarda i tuoi soldi: le '
                  'missioni che paghi, i premi che vinci, i rimborsi e i '
                  'prelievi. Con la data e con scritto dove sono passati.',
            ),
          ),
          final righe => ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            itemCount: righe.length,
            separatorBuilder: (_, _) => Divider(color: palette.line, height: 1),
            itemBuilder: (context, index) => _Riga(movimento: righe[index]),
          ),
        },
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.movimento});

  final LedgerEntry movimento;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    // Sotto il titolo: cosa e' successo, dove, e quando. Tre cose su una riga
    // sola, separate da un punto — tre righe impilate per ogni movimento
    // trasformerebbero un elenco di venti in un muro.
    final sotto = [
      if (movimento.note.isNotEmpty) movimento.note,
      if (movimento.dove.isNotEmpty) movimento.dove,
      if (movimento.at case final quando?) AppDateUtils.shortTimeAgo(quando),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  movimento.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.labelMedium,
                ),
                if (sotto.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sotto,
                    style: texts.labelSmall?.copyWith(color: palette.textFaint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // **Il segno c'e' sempre**, anche davanti a quello che entra: senza,
          // un premio e un pagamento della stessa cifra sono due righe uguali.
          Text(
            '${movimento.isIn ? '+' : ''}'
            '${AppMoney.format(movimento.amountCents)}',
            style: texts.titleSmall?.copyWith(
              color: movimento.isIn ? palette.accent : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
