import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:flutter/material.dart';

/// Apre un documento legale per esteso.
///
/// **Il testo si legge dentro l'app, non su una pagina web.** Un collegamento
/// che porta fuori dice, di fatto, "non leggerlo": si apre un'altra
/// applicazione, si perde il posto, e nove volte su dieci si torna indietro
/// senza aver letto niente. Qui il documento sale dal basso, si scorre e si
/// chiude, e chi voleva controllare una riga puo' farlo senza perdere la
/// registrazione a meta'.
Future<void> showLegalDocument(BuildContext context, LegalDocument document) {
  return ModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: document.title.toUpperCase(),
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: ConstrainedBox(
        // Il foglio non si prende tutto lo schermo: si deve continuare a vedere
        // che sotto c'e' la schermata da cui si e' arrivati, o sembra di essere
        // finiti altrove.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.62,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              document.body.trim(),
              style: sheetContext.texts.bodySmall?.copyWith(
                color: sheetContext.palette.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
