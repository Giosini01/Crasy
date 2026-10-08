import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/friends/presentation/widgets/verified_tick.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **La mancia.** Sostiene chi fa CRASY e, da dieci euro in su, da' la spunta
/// di verificato per sempre a un nome utente — il proprio o quello di un
/// amico. Sotto i dieci euro e' solo un grazie.
class TipPage extends ConsumerStatefulWidget {
  const TipPage({super.key});

  @override
  ConsumerState<TipPage> createState() => _TipPageState();
}

class _TipPageState extends ConsumerState<TipPage> {
  static const _scelte = [2, 5, 10, 20, 50];
  static const _perIlVerificato = 10;

  int _euro = _perIlVerificato;
  final _altro = TextEditingController();
  final _username = TextEditingController();
  bool _pago = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    final io = ref.read(currentUserProfileProvider).valueOrNull;
    _username.text = io?.username ?? '';
  }

  @override
  void dispose() {
    _altro.dispose();
    _username.dispose();
    super.dispose();
  }

  int get _importo {
    final scritto = int.tryParse(_altro.text.trim());

    return scritto ?? _euro;
  }

  Future<void> _paga() async {
    final euro = _importo;
    final chi = _username.text.trim().replaceFirst('@', '').toLowerCase();

    if (euro < 1 || euro > 500) {
      setState(() => _errore = 'La mancia va da 1 a 500 euro.');

      return;
    }

    if (chi.isEmpty) {
      setState(
        () => _errore = 'Scrivi il nome utente di chi riceve la spunta.',
      );

      return;
    }

    setState(() {
      _pago = true;
      _errore = null;
    });

    try {
      final fatto = await ref
          .read(paymentsServiceProvider)
          .payTip(amountCents: euro * 100, username: chi);

      if (!mounted) {
        return;
      }

      if (fatto) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Grazie!'),
            content: Text(
              euro >= _perIlVerificato
                  ? '@$chi è verificato per sempre. La spunta compare fra pochi '
                        'secondi.'
                  : 'Il tuo sostegno arriva a chi fa CRASY ogni giorno.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (mounted) {
          context.pop();
        }
      }
    } on Object catch (errore) {
      if (mounted) {
        setState(() => _errore = '$errore'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _pago = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final euro = _importo;
    final conSpunta = euro >= _perIlVerificato;

    return Scaffold(
      appBar: AppBar(title: const Text('Sostieni CRASY')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              'CRASY lo fanno poche persone, la sera, dopo il lavoro. Una mancia '
              'le aiuta a tenerlo vivo.',
              style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.accentTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const VerifiedBadge(size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Da $_perIlVerificato € in su, il nome che scrivi qui '
                      'sotto diventa verificato per sempre.',
                      style: texts.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'QUANTO',
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final e in _scelte)
                  ChoiceChip(
                    label: Text('$e €'),
                    selected: _altro.text.isEmpty && _euro == e,
                    onSelected: (_) => setState(() {
                      _euro = e;
                      _altro.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _altro,
              decoration: const InputDecoration(
                labelText: 'Altra cifra, in euro',
                hintText: 'da 1 a 500',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'CHI RICEVE LA SPUNTA',
              style: texts.labelSmall?.copyWith(color: palette.textFaint),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'nome utente, anche il tuo',
              ),
              autocorrect: false,
              textInputAction: TextInputAction.done,
            ),
            if (!conSpunta) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Sotto i $_perIlVerificato € è solo una mancia: la spunta no.',
                style: texts.bodySmall?.copyWith(color: palette.textFaint),
              ),
            ],
            if (_errore != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errore!,
                style: texts.bodySmall?.copyWith(color: palette.accent),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            CrasyButton(
              label: conSpunta ? 'Dona $euro € e verifica' : 'Dona $euro €',
              loading: _pago,
              onPressed: _pago ? null : _paga,
            ),
          ],
        ),
      ),
    );
  }
}
