import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/legal/presentation/widgets/privacy_settings.dart';
import 'package:crasy/features/profile/presentation/widgets/delete_account.dart';
import 'package:flutter/material.dart';

/// Le impostazioni del profilo: l'ingranaggio in alto a destra.
///
/// **Raccoglie le due voci che non si guardano mai e che devono restare
/// trovabili.** Privacy e cancellazione dell'account stavano in fondo alla
/// schermata, sotto le proprie foto: piccole, grigie, dopo una griglia che
/// cresce a ogni gara. Una porta che si allontana ogni volta che si vince non
/// e' una porta trovabile — ed e' un problema, perche' il GDPR chiede che
/// revocare un consenso sia facile quanto darlo, e cancellare l'account e' un
/// diritto che non deve costare una caccia al tesoro.
///
/// In alto a destra invece **stanno sempre nello stesso punto**, alla stessa
/// distanza dal pollice il primo giorno e dopo cento gare. Un tocco per aprire,
/// un tocco per scegliere: due, come prima, ma nessuno dei due e' uno scorrere
/// alla cieca fino in fondo.
///
/// **Non ci sta "Esci".** Uscire non e' un'impostazione, e' un gesto che si fa
/// spesso e in fretta: resta dov'e', in chiaro, senza un menu davanti.
Future<void> showProfileSettings(BuildContext context) async {
  final scelta = await ModalSheet.show<_SettingsChoice>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'IMPOSTAZIONI',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: _ProfileSettings(
        onPick: (voce) => Navigator.of(sheetContext).pop(voce),
      ),
    ),
  );

  // Il secondo foglio si apre **dopo** che il primo si e' chiuso, non sopra di
  // esso: due fogli impilati vogliono dire due tocchi su "Chiudi" per tornare
  // al profilo, e il secondo di quei tocchi nessuno se lo aspetta.
  if (scelta == null) {
    return;
  }

  // Fra l'apertura del primo foglio e la scelta puo' essere passato di tutto:
  // una disconnessione che riporta all'accesso, l'app chiusa e riaperta. Il
  // controllo va fatto **dopo** l'attesa, o si finisce a spingere una schermata
  // su un albero che non c'e' piu'.
  if (!context.mounted) {
    return;
  }

  await switch (scelta) {
    _SettingsChoice.privacy => showPrivacySettings(context),
    _SettingsChoice.deleteAccount => showDeleteAccount(context),
  };
}

enum _SettingsChoice { privacy, deleteAccount }

class _ProfileSettings extends StatelessWidget {
  const _ProfileSettings({required this.onPick});

  final void Function(_SettingsChoice scelta) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsRow(
          label: 'Privacy e consensi',
          note:
              'Cosa hai accettato, cosa puoi togliere, e i documenti da '
              'rileggere.',
          onTap: () => onPick(_SettingsChoice.privacy),
        ),
        Divider(color: palette.line, height: 1),
        // Staccata e rossa. **E' l'unica voce che non si disfa**, e deve
        // sembrarlo: in fila con le altre, prima o poi qualcuno la tocca al
        // posto di quella sopra.
        const SizedBox(height: AppSpacing.lg),
        _SettingsRow(
          label: 'Cancella account',
          note: 'Per sempre. Dentro c\'e\' scritto cosa sparisce e cosa resta.',
          danger: true,
          onTap: () => onPick(_SettingsChoice.deleteAccount),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.note,
    required this.onTap,
    this.danger = false,
  });

  final String label;

  /// La riga sotto: dice cosa si trova dall'altra parte.
  ///
  /// Serve perche' queste due porte si aprono una volta nella vita, e "privacy"
  /// da solo non dice se dentro c'e' un documento da leggere o un interruttore
  /// da spegnere.
  final String note;

  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final colore = danger ? palette.accent : palette.textPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: texts.titleMedium?.copyWith(color: colore)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    note,
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.textFaint),
          ],
        ),
      ),
    );
  }
}
