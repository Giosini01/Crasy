import 'package:crasy/core/moderation/age_policy.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Chiede la data di nascita **con il selettore del telefono su cui gira**.
///
/// Su iPhone la rotella che tutti conoscono, su Android il calendario di
/// Android. Non e' pignoleria: il selettore di una data e' uno degli attrezzi
/// che si usano da anni senza pensarci, e trovarne uno di un altro sistema
/// operativo fa fermare la mano. Su una schermata di registrazione, fermare la
/// mano vuol dire perdere qualcuno.
///
/// ## Nessuna data gia' scelta
///
/// **Si apre senza niente selezionato**, e ci si e' arrivati per un difetto
/// vero: prima partiva da una data che risultava gia' maggiorenne, quindi
/// bastava aprire e confermare senza toccare la rotella per ritrovarsi
/// registrati con un'eta' che nessuno aveva dichiarato. Un muro che si passa
/// premendo due volte "fatto" non e' un muro.
///
/// Su Android il calendario si apre vuoto e non si puo' confermare finche' non
/// si sceglie. Su iPhone la rotella un valore sotto la lente ce l'ha per forza,
/// quindi il valore di partenza e' **la soglia esatta dei diciotto anni**: chi
/// conferma senza toccare niente dichiara di averli compiuti oggi, che e' la
/// cosa piu' onesta che si possa mettere li'.
Future<DateTime?> pickBirthDate(BuildContext context, {DateTime? current}) {
  // La piu' recente data di nascita che risulta maggiorenne oggi: chi e'
  // minorenne **non riesce nemmeno a sceglierla**, una data che poi verrebbe
  // rifiutata. Un limite che si vede prima e' molto meglio di un errore dopo.
  final soglia = AgePolicy.latestAdultBirthDate();
  final prima = DateTime(1920);

  final cupertino =
      Theme.of(context).platform == TargetPlatform.iOS ||
      Theme.of(context).platform == TargetPlatform.macOS;

  if (!cupertino) {
    return showDatePicker(
      context: context,
      initialDate: current,
      firstDate: prima,
      lastDate: soglia,
      helpText: 'QUANDO SEI NATO',
      cancelText: 'ANNULLA',
      confirmText: 'FATTO',
    );
  }

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _CupertinoBirthDate(
      initial: current ?? soglia,
      first: prima,
      last: soglia,
    ),
  );
}

class _CupertinoBirthDate extends StatefulWidget {
  const _CupertinoBirthDate({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_CupertinoBirthDate> createState() => _CupertinoBirthDateState();
}

class _CupertinoBirthDateState extends State<_CupertinoBirthDate> {
  late DateTime _scelta = widget.initial;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      // Un terzo del margine di sicurezza, come in tutto il resto dell'app:
      // quello pieno lascia sotto una fascia vuota che sembra uno scalino.
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom * 0.34,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annulla'),
                  ),
                  Expanded(
                    child: Text(
                      'QUANDO SEI NATO',
                      textAlign: TextAlign.center,
                      style: context.texts.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_scelta),
                    child: Text(
                      'Fatto',
                      style: context.texts.labelLarge?.copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: palette.line, height: 0.5, thickness: 0.5),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: widget.initial,
                minimumDate: widget.first,
                maximumDate: widget.last,
                // Giorno, mese, anno: l'ordine italiano. Con quello americano
                // si sbaglia a colpo sicuro nei primi dodici giorni del mese.
                dateOrder: DatePickerDateOrder.dmy,
                onDateTimeChanged: (data) => _scelta = data,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
