import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// **Lanciare senza farsi vedere.**
///
/// Lo stesso interruttore per le missioni e per le sfide uno contro uno, e
/// sulle seconde e' quello che conta: "qualcuno dei tuoi amici ti ha sfidato,
/// indovina chi" e' una sfida diversa da quella firmata, e un po' piu' calda.
///
/// Spento di partenza. Firmare e' la strada normale, e chi si nasconde deve
/// averlo scelto — non trovarselo acceso senza saperlo.
///
/// La riga sotto dice il prezzo prima che lo si paghi: **in anonimo non si
/// sale nella classifica di chi fa giocare.** Una classifica col tuo nome
/// accanto ai soldi della sfida svelerebbe la maschera.
class AnonimoSwitch extends StatelessWidget {
  const AnonimoSwitch({
    required this.acceso,
    required this.onCambia,
    this.sfida = false,
    super.key,
  });

  final bool acceso;
  final ValueChanged<bool> onCambia;

  /// Una sfida a una persona sola: la spiegazione parla di "lui", non di
  /// "chi partecipa".
  final bool sfida;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    final spiegazione = acceso
        ? (sfida
              ? 'Vedrà solo “Un anonimo ti ha sfidato”: niente nome, niente '
                    'foto. Indovinare chi sei è il gioco. In anonimo non sali '
                    'nella classifica di chi fa giocare.'
              : 'Nessuno vedrà che l’hai lanciata tu: niente nome, niente '
                    'foto, e non comparirà sul tuo profilo. In anonimo non '
                    'sali nella classifica di chi fa giocare.')
        : (sfida ? 'Vedrà il tuo nome.' : 'Chi la vede legge il tuo nome.');

    return GestureDetector(
      onTap: () => onCambia(!acceso),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.theater_comedy_rounded,
                size: 20,
                color: acceso ? palette.accent : palette.textFaint,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Lancia in anonimo',
                  style: texts.bodyMedium?.copyWith(
                    color: acceso ? palette.textPrimary : palette.textSecondary,
                    fontWeight: acceso ? FontWeight.w700 : null,
                  ),
                ),
              ),
              Switch.adaptive(
                value: acceso,
                onChanged: onCambia,
                activeThumbColor: palette.accent,
              ),
            ],
          ),
          Text(
            spiegazione,
            style: texts.bodySmall?.copyWith(color: palette.textFaint),
          ),
        ],
      ),
    );
  }
}
