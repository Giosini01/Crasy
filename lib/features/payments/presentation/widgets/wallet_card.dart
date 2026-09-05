import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/entities/wallet.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il portafoglio, in cima al profilo.
///
/// E' l'unico riquadro colorato dell'app e si merita l'eccezione: e' il posto
/// in cui CRASY mantiene la promessa che fa in home. Sta in cima perche' e'
/// l'unica cosa del profilo che **vale del denaro**.
///
/// Sotto il saldo c'e' scritto **dove sono quei soldi**, e non e' una nota
/// legale: un portafoglio che mostra un numero senza dire dove sta e' la cosa
/// piu' vicina a una truffa che si possa costruire in buona fede.
class WalletCard extends ConsumerStatefulWidget {
  const WalletCard({super.key});

  @override
  ConsumerState<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends ConsumerState<WalletCard> {
  bool _working = false;
  String? _message;

  Future<void> _withdraw() async {
    setState(() {
      _working = true;
      _message = null;
    });

    final payments = ref.read(paymentsServiceProvider);

    try {
      final reason = await payments.withdraw();

      if (!mounted) {
        return;
      }

      if (reason == null) {
        setState(() {
          _working = false;
          _message = 'Fatto. Arrivano sul tuo conto in pochi giorni.';
        });

        return;
      }

      if (reason == 'account-mancante') {
        // Il caso normale della prima volta. Non e' un errore: e' il momento in
        // cui bisogna dire chi si e', e la pagina che si apre lo chiede.
        await payments.startPayoutOnboarding();

        if (mounted) {
          setState(() {
            _working = false;
            _message =
                'Finisci la registrazione nella pagina che si è aperta, poi '
                'torna qui e premi di nuovo.';
          });
        }

        return;
      }

      setState(() {
        _working = false;
        _message = reason == 'saldo-basso'
            ? 'Servono almeno '
                  '${AppMoney.format(Wallet.minimumWithdrawalCents)} per '
                  'prelevare.'
            : 'Non ci siamo riusciti. Riprova fra poco.';
      });
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _message = 'Non ci siamo riusciti. Riprova fra poco.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();
    final balance = ref.watch(walletBalanceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PORTAFOGLIO',
            style: texts.labelSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppMoney.format(balance),
                style: texts.displaySmall?.copyWith(color: palette.accent),
              ),
              const Spacer(),
              if (paymentsEnabled && wallet.balanceCents > 0)
                TextButton(
                  onPressed: _working ? null : _withdraw,
                  child: Text(
                    _working ? 'Un attimo...' : 'Preleva',
                    style: texts.titleMedium?.copyWith(color: palette.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _note(wallet),
            style: texts.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_message!, style: texts.bodySmall),
          ],
          if (wallet.movements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final movement in wallet.movements.take(5))
              _MovementRow(movement: movement),
          ],
        ],
      ),
    );
  }

  /// La riga sotto il saldo. Dice tre cose diverse in tre situazioni diverse, e
  /// nessuna delle tre e' un ornamento.
  String _note(Wallet wallet) {
    if (!paymentsEnabled) {
      return 'Quanto hai vinto finora. I pagamenti non sono ancora attivi, '
          'quindi questi soldi te li deve chi ha lanciato la challenge: CRASY '
          'non li ha in cassa e non fa da garante. Quando i pagamenti saranno '
          'accesi, li troverai qui e li potrai prelevare.';
    }

    if (wallet.balanceCents <= 0) {
      return 'Qui finiscono i premi che vinci. Restano su CRASY finché non '
          'li prelevi.';
    }

    if (!wallet.canWithdraw) {
      return 'I soldi sono tuoi e stanno su CRASY. Da '
          '${AppMoney.format(Wallet.minimumWithdrawalCents)} in su li puoi '
          'prelevare sul tuo conto.';
    }

    return 'I soldi sono tuoi e stanno su CRASY. La prima volta che prelevi '
        'servono nome, documento e IBAN: è la legge per chiunque riceva '
        'denaro, e si fa una volta sola.';
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final WalletMovement movement;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final createdAt = movement.createdAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              movement.label,
              style: texts.labelSmall?.copyWith(color: palette.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (createdAt != null) ...[
            Text(
              AppDateUtils.shortTimeAgo(createdAt),
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            // Il segno si scrive sempre, anche sul piu': una colonna di numeri
            // in cui solo alcuni hanno il meno si legge male, e questi numeri
            // sono soldi.
            '${movement.isPrize ? '+' : '-'}'
            '${AppMoney.format(movement.amountCents.abs())}',
            style: texts.labelMedium?.copyWith(
              color: movement.isPrize ? palette.accent : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quanto ha vinto una persona, sul suo profilo pubblico.
///
/// Ha la stessa faccia del portafoglio e dice una cosa diversa: quello e' il
/// saldo di adesso, questo e' **il totale di sempre**. Il primo scende quando
/// uno preleva — cioe' proprio nel momento in cui CRASY ha mantenuto la
/// promessa meglio — e sarebbe assurdo che il profilo di chi ha vinto e
/// incassato mille euro dicesse zero.
class PrizeTotalCard extends StatelessWidget {
  const PrizeTotalCard({required this.prizeCents, super.key});

  final int prizeCents;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final won = prizeCents > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Senza vittorie il riquadro resta grigio: il rosso e' il colore dei
        // soldi, e acceso su uno zero sarebbe una promessa mancata scritta a
        // colori.
        color: won ? palette.accentTint : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HA VINTO',
            style: texts.labelSmall?.copyWith(
              color: won ? palette.accent : palette.textFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppMoney.format(prizeCents),
            style: texts.displaySmall?.copyWith(
              color: won ? palette.accent : palette.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
