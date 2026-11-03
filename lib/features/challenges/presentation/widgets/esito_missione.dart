import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Cosa succede quando si preme il tasto, detto prima di premerlo.**
///
/// Sta sopra il tasto del lancio, nel modulo e nella sfida. E' la risposta alla domanda
/// che uno si fa con un premio scritto sullo schermo: **quando mi prendono i soldi?**
/// Solo dopo il controllo, e mai per una missione che non esce.
class AvvisoPrimaDelLancio extends StatelessWidget {
  const AvvisoPrimaDelLancio({required this.conPremio, super.key});

  /// Con un premio si parla di soldi; gratis no.
  final bool conPremio;

  static const conPremioTesto =
      'Prima di uscire la controlliamo, in pochi secondi. Se è tutto a posto si '
      'apre il pagamento: i soldi li prendiamo solo in quel momento. Se deve '
      'guardarla una persona del team non paghi niente: ti avvisiamo appena è '
      'approvata, e paghi solo allora. Se non può uscire, non paghi mai.';

  static const gratisTesto =
      'Prima di uscire la controlliamo, in pochi secondi. Se deve guardarla una '
      'persona del team, ti avvisiamo appena c’è una risposta.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: palette.accent),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            conPremio ? conPremioTesto : gratisTesto,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// **"Approvata, adesso si paga": una riga sola, mentre si apre il pagamento.**
///
/// Il controllo e' passato e sta per comparire il foglio di Stripe. Senza questa riga
/// sembra che il tasto abbia saltato un passaggio.
void avvisaApprovata(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Missione approvata: ora paghi il premio e parte.'),
    ),
  );
}

/// **"Una persona la sta guardando", in un foglio.**
///
/// Compare appena si preme "Lancia" su una missione che il controllo automatico
/// non se la sente di far uscire da sola. Non e' un errore, e non deve sembrarlo:
/// chi ha scritto la missione non ha sbagliato niente, sta solo aspettando.
///
/// Dice le tre cose che chi aspetta si chiede subito: **chi la guarda**, **se ha
/// gia' pagato** e **come sapra' la risposta**. La seconda e' quella che conta di
/// piu': e' l'unica volta in cui si preme un tasto con scritto "paga" e non parte
/// nessun pagamento, e senza dirlo si va a controllare l'estratto conto.
Future<void> mostraMissioneInControllo(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (foglio) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AvvisoInControllo(),
            const SizedBox(height: AppSpacing.lg),
            CrasyButton(
              label: 'Ho capito',
              onPressed: () => Navigator.of(foglio).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// La stessa frase nel foglio qui sopra e nella pagina della missione.
class AvvisoInControllo extends StatelessWidget {
  const AvvisoInControllo({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DisplayTitle('È in controllo'),
        const SizedBox(height: AppSpacing.md),
        Text('Una persona del team la guarda.', style: texts.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Non paghi niente finché non è approvata.',
          style: texts.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Ti avvisiamo appena c’è una risposta.', style: texts.bodyLarge),
      ],
    );
  }
}

/// **Perche' una missione non puo' uscire, in un foglio.**
///
/// Si apre toccando l'avviso in campanella. Il Digital Services Act chiede tre
/// cose a chi ferma un contenuto: **il motivo**, **chi ha deciso** e **come si
/// contesta**. Ci sono tutte e tre, piu' quella che uno si chiede per prima: i
/// soldi. Una missione rifiutata non e' mai stata pagata.
Future<void> mostraMissioneRifiutata(
  BuildContext context, {
  required String titolo,
  required String motivo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: AvvisoRifiutata(titolo: titolo, motivo: motivo),
      ),
    ),
  );
}

/// Il perche' di un no: lo stesso nel foglio e nella pagina della missione.
class AvvisoRifiutata extends StatelessWidget {
  const AvvisoRifiutata({
    required this.titolo,
    required this.motivo,
    this.daUnaPersona = true,
    super.key,
  });

  final String titolo;

  /// Quello che ha scritto chi ha deciso. Vuoto, non si inventa niente.
  final String motivo;

  /// Falso se la missione si e' fermata alle parole, senza che la guardasse
  /// nessuno: scrivere "l'ha decisa una persona" sarebbe una bugia.
  final bool daUnaPersona;

  /// Dove si scrive per contestare. E' la casella che legge davvero qualcuno.
  static const _casella = 'info@crasyapp.com';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DisplayTitle('Non può uscire'),
        if (titolo.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            titolo.toUpperCase(),
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          motivo.isEmpty ? 'Non rispetta le regole delle missioni.' : motivo,
          style: texts.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        if (daUnaPersona) ...[
          const _Segno(
            icona: Icons.person_outline_rounded,
            testo: 'L’ha decisa una persona del team.',
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        const _Segno(
          icona: Icons.euro_rounded,
          testo: 'Non hai pagato niente.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Puoi riscriverla e lanciarla di nuovo. Se pensi che sia un errore, '
          'scrivi a $_casella: una persona del team riguarda la decisione.',
          style: texts.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => launchUrl(
            Uri(
              scheme: 'mailto',
              path: _casella,
              query: titolo.isEmpty
                  ? null
                  : 'subject=${Uri.encodeComponent('Missione: $titolo')}',
            ),
          ),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: const Text('Scrivici'),
        ),
      ],
    );
  }
}

/// Un segno e una frase: chi ha deciso, e cosa e' successo ai soldi.
class _Segno extends StatelessWidget {
  const _Segno({required this.icona, required this.testo});

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icona, size: 18, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            testo,
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
