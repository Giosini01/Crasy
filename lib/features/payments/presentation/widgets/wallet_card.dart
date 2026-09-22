import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/domain/entities/wallet.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Il portafoglio, in cima al profilo.
///
/// E' l'unico riquadro colorato dell'app e si merita l'eccezione: e' il posto
/// in cui CRASY mantiene la promessa che fa in home. Sta in cima perche' e'
/// l'unica cosa del profilo che **vale del denaro**.
///
/// **Dice quanto, e si apre.** Il prelievo stava qui dentro, in un tasto
/// piccolo accanto alla cifra, in mezzo a una schermata che parla di tutt'altro
/// — le foto, le figurine, gli amici. Adesso sta nella sua schermata, con i
/// movimenti per esteso e la registrazione spiegata: questo riquadro e' il modo
/// di accorgersene passando.
///
/// Due posti che fanno la stessa cosa sarebbero due posti da tenere d'accordo,
/// e il giorno in cui una regola cambia ne resta indietro uno.
class WalletCard extends ConsumerWidget {
  const WalletCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final wallet = ref.watch(walletProvider).valueOrNull ?? const Wallet();
    final balance = ref.watch(walletBalanceProvider);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.wallet),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.accentTint,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'PORTAFOGLIO',
                  style: texts.labelSmall?.copyWith(color: palette.accent),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppMoney.format(balance),
              style: texts.displaySmall?.copyWith(color: palette.accent),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _note(wallet),
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// La riga sotto il saldo. Dice tre cose diverse in tre situazioni diverse, e
  /// nessuna delle tre e' un ornamento.
  String _note(Wallet wallet) {
    if (!paymentsEnabled) {
      return 'Quanto hai vinto finora. I pagamenti non sono ancora attivi, '
          'quindi questi soldi te li deve chi ha lanciato la challenge: CRASY '
          'non li ha in cassa e non fa da garante.';
    }

    if (wallet.balanceCents <= 0) {
      return 'Qui finiscono i premi che vinci. Restano su CRASY finché non li '
          'prelevi.';
    }

    if (!wallet.canWithdraw) {
      return 'I soldi sono tuoi e stanno su CRASY. Da '
          '${AppMoney.format(Wallet.minimumWithdrawalCents)} in su li puoi '
          'prelevare sul tuo conto.';
    }

    return 'Puoi prelevarli: tocca qui.';
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
