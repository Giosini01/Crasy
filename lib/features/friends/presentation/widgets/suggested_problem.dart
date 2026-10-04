import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:flutter/material.dart';

/// **Perche' i suggeriti non ci sono, detto giusto.**
///
/// Prima tre casi diversi davano la stessa frase — "serve il permesso" — anche
/// quando il permesso c'era gia' (rubrica vuota) o quando era caduta la rete.
/// E dopo un "no" definitivo l'unica strada, l'interruttore nelle impostazioni,
/// andava cercata a mano. Adesso ogni caso ha la sua frase, e il tasto porta
/// direttamente dove serve.
class SuggestedProblem extends StatelessWidget {
  const SuggestedProblem({
    required this.errore,
    required this.onRiprova,
    this.piccolo = false,
    super.key,
  });

  final Object? errore;
  final VoidCallback onRiprova;

  /// Nel cassetto del profilo il testo e' piu' piccolo.
  final bool piccolo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stile = (piccolo ? context.texts.bodySmall : context.texts.bodyMedium)
        ?.copyWith(color: palette.textFaint);

    final (
      String testo,
      String tasto,
      void Function() azione,
    ) = switch (errore) {
      ContattiNegati(perSempre: true) => (
        'Per vedere chi conosci serve il permesso sui contatti. Il telefono '
            'non lo chiede più: si accende dalle impostazioni, alla voce CRASY.',
        'APRI IMPOSTAZIONI',
        ContactsRepository.apriImpostazioni,
      ),
      ContattiNegati() => (
        'Per vedere chi conosci serve il permesso sui contatti. Dalla rubrica '
            'prendiamo solo i numeri, e non li salviamo.',
        'DAI IL PERMESSO',
        onRiprova,
      ),
      RubricaVuota() => (
        'In rubrica non abbiamo trovato numeri da confrontare. Se su iPhone '
            'hai scelto "solo alcuni contatti", aggiungine altri dalle '
            'impostazioni.',
        'APRI IMPOSTAZIONI',
        ContactsRepository.apriImpostazioni,
      ),
      _ => (
        'Non siamo riusciti a cercare: controlla la connessione.',
        'RIPROVA',
        onRiprova,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(testo, style: stile),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => azione(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: palette.accent,
          ),
          child: Text(tasto),
        ),
      ],
    );
  }
}
