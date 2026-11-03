import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/payments/domain/prize_ledger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Cosa succede quando si preme il tasto, detto prima di premerlo.**
///
/// Sta sopra il tasto del lancio, nel modulo e nella sfida. E' la risposta alla domanda
/// che uno si fa con un premio scritto sullo schermo: **quando mi prendono i soldi?**
/// Al lancio, dopo il controllo automatico. E se poi la missione non esce, cosa torna.
class AvvisoPrimaDelLancio extends StatelessWidget {
  const AvvisoPrimaDelLancio({required this.conPremio, super.key});

  /// Con un premio si parla di soldi; gratis no.
  final bool conPremio;

  static const conPremioTesto =
      'Prima di uscire la controlliamo, in pochi secondi. Se è tutto a posto '
      'esce appena paghi. Se deve guardarla una persona del team paghi lo stesso e '
      'la missione resta in pausa: se viene accettata esce e parte il tempo, se '
      'non viene accettata ti tornano i soldi, tranne le commissioni di Stripe. Se '
      'si ferma alle parole vietate non paghi niente.';

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
/// Dice le due cose che chi aspetta si chiede subito: **chi la guarda** e **come
/// sapra' la risposta**.
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
        Text('Ti avvisiamo appena c’è una risposta.', style: texts.bodyLarge),
      ],
    );
  }
}

/// **Prima di pagare, tutto quello che succede ai soldi.**
///
/// Si paga una missione che potrebbe non uscire mai: chi lo fa deve saperlo adesso, con le
/// cifre, non scoprirlo leggendo un rimborso piu' basso di quello che ha pagato. Compare
/// ogni volta che si sta per pagare, anche riprovando. Torna vero solo se si conferma.
Future<bool> chiediConfermaRevisione(
  BuildContext context, {
  required int premioCents,
}) async {
  final risposta = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (foglio) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AvvisoPrimaDellaRevisione(premioCents: premioCents),
            const SizedBox(height: AppSpacing.lg),
            CrasyButton(
              label: 'Paga e mandala in revisione',
              onPressed: () => Navigator.of(foglio).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(foglio).pop(false),
              child: const Text('Non adesso'),
            ),
          ],
        ),
      ),
    ),
  );

  return risposta == true;
}

/// Il testo del foglio qui sopra. Le cifre sono quelle del conto che si legge nel modulo.
class AvvisoPrimaDellaRevisione extends StatelessWidget {
  const AvvisoPrimaDellaRevisione({required this.premioCents, super.key});

  final int premioCents;

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;
    final pagato = PrizeLedger.chargeCents(premioCents);
    final commissioni = PrizeLedger.processingFeeCents(premioCents);
    final torna = pagato - commissioni;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DisplayTitle('Prima la controlliamo'),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Questa missione deve guardarla una persona del team prima di uscire.',
          style: texts.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        _Segno(
          icona: Icons.euro_rounded,
          testo:
              'Paghi adesso. Con la carta sono ${AppMoney.format(pagato)}: il premio '
              'di ${AppMoney.format(premioCents)} più le spese. Dal portafoglio '
              'paghi solo il premio.',
        ),
        const SizedBox(height: AppSpacing.xs),
        const _Segno(
          icona: Icons.pause_circle_outline_rounded,
          testo:
              'Finché non è accettata resta in pausa: non la vede nessuno e il tempo '
              'non parte.',
        ),
        const SizedBox(height: AppSpacing.xs),
        const _Segno(
          icona: Icons.check_circle_outline_rounded,
          testo: 'Se viene accettata esce subito, e il tempo parte da lì.',
        ),
        const SizedBox(height: AppSpacing.xs),
        _Segno(
          icona: Icons.undo_rounded,
          testo:
              'Se non viene accettata i soldi tornano indietro: sulla carta '
              '${AppMoney.format(torna)}, cioè tutto tranne le commissioni di Stripe '
              '(circa ${AppMoney.format(commissioni)}), che non si recuperano. Dal '
              'portafoglio torna tutto nel portafoglio.',
        ),
        const SizedBox(height: AppSpacing.xs),
        const _Segno(
          icona: Icons.schedule_rounded,
          testo:
              'Se entro 48 ore non ti rispondiamo non viene caricata, e i soldi tornano '
              'nello stesso modo.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sulla carta la banca ci mette 5-10 giorni lavorativi.',
          style: texts.bodySmall?.copyWith(color: context.palette.textFaint),
        ),
      ],
    );
  }
}

/// **"E' in revisione", appena pagato.** Non e' uscita e non e' un errore: i soldi sono
/// arrivati, e adesso si aspetta una persona.
Future<void> mostraMissioneInRevisione(BuildContext context) {
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
            const AvvisoInRevisione(),
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

/// La stessa frase nel foglio qui sopra e nella pagina dove si torna da Stripe, sul sito.
class AvvisoInRevisione extends StatelessWidget {
  const AvvisoInRevisione({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DisplayTitle('È in revisione'),
        const SizedBox(height: AppSpacing.md),
        Text(
          'La tua missione è in pausa finché una persona del team non la guarda.',
          style: texts.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ti avvisiamo appena c’è una risposta, entro 48 ore.',
          style: texts.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Se non viene accettata i soldi tornano indietro, tranne le commissioni '
          'di Stripe.',
          style: texts.bodyLarge,
        ),
      ],
    );
  }
}

/// **"Non e' stata caricata": sono passate 48 ore senza risposta.** Senza troppe
/// spiegazioni: cosa e' successo, e dove sono i soldi.
Future<void> mostraMissioneNonCaricata(
  BuildContext context, {
  required String titolo,
  int rimborsoCents = 0,
  String rimborsoDove = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: AvvisoNonCaricata(
          titolo: titolo,
          rimborsoCents: rimborsoCents,
          rimborsoDove: rimborsoDove,
        ),
      ),
    ),
  );
}

class AvvisoNonCaricata extends StatelessWidget {
  const AvvisoNonCaricata({
    required this.titolo,
    this.rimborsoCents = 0,
    this.rimborsoDove = '',
    super.key,
  });

  final String titolo;
  final int rimborsoCents;
  final String rimborsoDove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DisplayTitle('Non è stata caricata'),
        if (titolo.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            titolo.toUpperCase(),
            style: texts.labelSmall?.copyWith(color: palette.textFaint),
          ),
        ],
        if (rimborsoCents > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          _Segno(
            icona: Icons.euro_rounded,
            testo: fraseDelRimborso(rimborsoCents, rimborsoDove),
          ),
        ],
      ],
    );
  }
}

/// Quanto e' tornato e dove: la stessa frase in tutti gli avvisi.
String fraseDelRimborso(int cents, String dove) {
  final quanto = AppMoney.format(cents);

  return dove == 'portafoglio'
      ? 'Ti sono tornati $quanto nel portafoglio.'
      : 'Ti abbiamo rimborsato $quanto sulla carta: le commissioni di Stripe non si '
            'recuperano. La banca ci mette 5-10 giorni lavorativi.';
}

/// **Perche' una missione non puo' uscire, in un foglio.**
///
/// Si apre toccando l'avviso in campanella. Il Digital Services Act chiede tre
/// cose a chi ferma un contenuto: **il motivo**, **chi ha deciso** e **come si
/// contesta**. Ci sono tutte e tre, piu' quella che uno si chiede per prima: i
/// soldi. Se aveva gia' pagato si dice quanto gli e' tornato.
Future<void> mostraMissioneRifiutata(
  BuildContext context, {
  required String titolo,
  required String motivo,
  int rimborsoCents = 0,
  String rimborsoDove = '',
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
        child: AvvisoRifiutata(
          titolo: titolo,
          motivo: motivo,
          rimborsoCents: rimborsoCents,
          rimborsoDove: rimborsoDove,
        ),
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
    this.rimborsoCents = 0,
    this.rimborsoDove = '',
    super.key,
  });

  final String titolo;

  /// Quanto gli e' tornato, se aveva gia' pagato. Zero: non aveva pagato niente.
  final int rimborsoCents;

  /// `carta` o `portafoglio`.
  final String rimborsoDove;

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
        _Segno(
          icona: Icons.euro_rounded,
          testo: rimborsoCents > 0
              ? fraseDelRimborso(rimborsoCents, rimborsoDove)
              : 'Non hai pagato niente.',
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
