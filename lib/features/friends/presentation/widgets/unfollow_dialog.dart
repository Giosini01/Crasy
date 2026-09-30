import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// **Chiede conferma prima di smettere di seguire un amico.**
///
/// Con chi non ti segue smettere e' un tocco e basta: non si perde niente. Con
/// un amico si perde l'amicizia — e con lei le sfide — quindi si chiede una
/// volta. Torna `true` se si conferma.
Future<bool> confermaSmettiDiSeguire(
  BuildContext context, {
  required String username,
}) async {
  final palette = context.palette;

  final si = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Smetti di seguire @$username?'),
      content: const Text(
        'Non sarete più amici e non potrete sfidarvi. Lui continua a seguirti: '
        'se cambi idea, lo ritrovi fra i tuoi follower e puoi ricambiare.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Smetti', style: TextStyle(color: palette.accent)),
        ),
      ],
    ),
  );

  return si ?? false;
}
