import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/profile/presentation/controllers/delete_account_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chiudere l'account, per sempre.
///
/// **Dice cosa resta, non solo cosa sparisce.** Una schermata che promette
/// "cancelliamo tutto" e poi lascia in giro le foto di una gara ancora aperta
/// mente, e lo si scopre nel momento peggiore — quando qualcuno cerca la propria
/// roba e la trova. Meglio scriverlo prima: le foto in gara restano fino alla
/// fine della gara, poi se ne vanno con quelle di tutti gli altri.
Future<void> showDeleteAccount(BuildContext context) {
  return ModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'CANCELLA ACCOUNT',
      confirmLabel: 'Annulla',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: const _DeleteAccount(),
    ),
  );
}

class _DeleteAccount extends ConsumerStatefulWidget {
  const _DeleteAccount();

  @override
  ConsumerState<_DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<_DeleteAccount> {
  final _password = TextEditingController();

  /// Il primo tocco chiede conferma, il secondo cancella.
  ///
  /// **Due passaggi per una cosa che non si disfa.** Non e' una finestra "sei
  /// sicuro?" che si tocca senza leggere: qui in mezzo ci si deve fermare a
  /// scrivere la propria password, e quel gesto e' abbastanza lungo da far
  /// tornare in mente che si sta buttando via tutto.
  bool _confirming = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final state = ref.watch(deleteAccountControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Spariscono per sempre',
          style: texts.titleMedium?.copyWith(color: palette.accent),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Il tuo profilo e la foto, le fiamme che hai dato, le notifiche, le '
          'amicizie, e le foto mandate a gare gia'
          r"'"
          ' finite. '
          'Non si torna indietro e non si recupera niente.',
          style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Restano ancora un po'
          r"'",
          style: texts.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Le foto che hai in gare ancora aperte: toglierle mentre gli altri '
          'stanno giocando non sarebbe giusto verso di loro. Alla chiusura '
          'vengono cancellate insieme a quelle di tutti. La foto con cui hai '
          'vinto resta come trofeo della gara di chi l'
          r"'"
          'aveva pagata.',
          style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_confirming) ...[
          Text(
            'Scrivi la tua password per confermare.',
            style: texts.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            style: texts.bodyLarge,
            decoration: const InputDecoration(hintText: 'Password'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (state.hasError) ...[
          InlineBanner(message: ErrorMessageMapper.map(state.error!)),
          const SizedBox(height: AppSpacing.md),
        ],
        CrasyButton(
          label: _confirming
              ? 'Cancella tutto'
              : 'Voglio cancellare l\'account',
          loading: state.isLoading,
          onPressed: _step,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Future<void> _step() async {
    if (!_confirming) {
      setState(() => _confirming = true);

      return;
    }

    final gone = await ref
        .read(deleteAccountControllerProvider.notifier)
        .delete(_password.text);

    // A account cancellato il router riporta all'ingresso da solo: qui si
    // chiude solo il foglio, che altrimenti resterebbe aperto sopra la
    // schermata di accesso di uno che non esiste piu'.
    if (gone && mounted) {
      Navigator.of(context).pop();
    }
  }
}
