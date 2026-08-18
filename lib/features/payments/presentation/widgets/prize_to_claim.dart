import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Hai vinto. Prendi i soldi."
///
/// E' l'unico riquadro colorato di tutta l'app, e si merita l'eccezione: e' il
/// momento in cui CRASY mantiene la sua promessa, ed e' anche l'unica cosa
/// dell'app che **vale del denaro se la si ignora**. Sta in cima al profilo e
/// non in una schermata a parte per la stessa ragione.
///
/// Il bottone fa una cosa sola vista da fuori — incassa — ma dietro ne prova
/// due: prima chiede al server di pagare, e solo se il server risponde che
/// manca il conto apre la registrazione. Chiedere prima "vuoi registrarti?" a
/// chi si e' gia' registrato la volta scorsa sarebbe un passaggio in piu' ogni
/// volta, per un caso che capita una volta sola.
class PrizeToClaim extends ConsumerStatefulWidget {
  const PrizeToClaim({required this.challenge, super.key});

  final Challenge challenge;

  @override
  ConsumerState<PrizeToClaim> createState() => _PrizeToClaimState();
}

class _PrizeToClaimState extends ConsumerState<PrizeToClaim> {
  bool _working = false;
  String? _message;

  Future<void> _claim() async {
    setState(() {
      _working = true;
      _message = null;
    });

    final payments = ref.read(paymentsServiceProvider);

    try {
      final paid = await payments.claimPrize(widget.challenge.id);

      if (!mounted) {
        return;
      }

      if (paid) {
        setState(() {
          _working = false;
          _message = 'Fatto. I soldi arrivano sul tuo conto in pochi giorni.';
        });

        return;
      }

      // Non e' un errore: e' il caso normale della prima vittoria. Prima di
      // poter ricevere del denaro serve dire chi si e', e lo dice la pagina che
      // si apre adesso.
      await payments.startPayoutOnboarding();

      if (mounted) {
        setState(() {
          _working = false;
          _message =
              'Finisci la registrazione nella pagina che si e\' aperta, poi '
              'torna qui e premi di nuovo.';
        });
      }
    } catch (error) {
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
    final amount = PrizeLedger.payoutCents(widget.challenge.prizeCents);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HAI VINTO',
            style: texts.labelSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            widget.challenge.title.toUpperCase(),
            style: texts.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                AppMoney.format(amount),
                style: texts.headlineSmall?.copyWith(color: palette.accent),
              ),
              const Spacer(),
              TextButton(
                onPressed: _working ? null : _claim,
                child: Text(
                  _working ? 'Un attimo...' : 'Incassa',
                  style: texts.titleMedium?.copyWith(color: palette.accent),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_message!, style: texts.bodySmall),
          ] else ...[
            const SizedBox(height: AppSpacing.xxs),
            // Detto qui e non dopo aver premuto: scoprire di dover mandare un
            // documento **mentre** si aspettano dei soldi che si sono gia'
            // vinti e' il momento peggiore per scoprirlo.
            Text(
              'La prima volta servono nome, documento e IBAN: e\' la legge per '
              'chiunque riceva del denaro, e si fa una volta sola.',
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
