import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/features/gioco/domain/sfide_in_vista.dart';
import 'package:crasy/features/gioco/presentation/providers/gioco_providers.dart';
import 'package:crasy/features/gioco/presentation/widgets/gioco_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Le sfide: quelle di oggi e i traguardi di sempre.**
///
/// Non c'e' nessun tasto "fatto": le sfide si completano giocando. Una foto
/// approvata, una fiamma, un'amicizia — il server le conta mentre succedono,
/// e questa schermata si aggiorna da sola, anche se la cosa la si e' fatta da
/// un altro telefono.
class SfidePage extends ConsumerStatefulWidget {
  const SfidePage({super.key});

  @override
  ConsumerState<SfidePage> createState() => _SfidePageState();
}

class _SfidePageState extends ConsumerState<SfidePage> {
  @override
  void initState() {
    super.initState();

    // **Ogni volta che si apre, il giorno lo chiede al server.** Chi ha
    // lasciato l'app aperta da ieri sera trova le sfide di oggi, non quelle
    // di ieri; e l'orologio del telefono non c'entra.
    Future(() async {
      try {
        await ref.read(giocoRepositoryProvider)?.apri();
      } on Object {
        // Senza rete si vede l'ultima giornata salvata.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final regole = ref.watch(regoleDelGiocoProvider);
    final stato = ref.watch(statoDelGiocoProvider);
    final livello = ref.watch(livelloAttualeProvider);
    final oggi = ref.watch(sfideDiOggiProvider);
    final traguardi = ref.watch(traguardiProvider);
    final caricando =
        (!regole.hasValue && !regole.hasError) ||
        (!stato.hasValue && !stato.hasError) ||
        (regole.hasValue && regole.value == null);
    final guasto =
        (regole.hasError && !regole.hasValue) ||
        (stato.hasError && !stato.hasValue);

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Sfide')),
      body: AppBackground(
        child: guasto
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: EmptyState(
                  title: 'Sfide non disponibili',
                  message: 'Non riusciamo a leggerle. Riprova tra poco.',
                ),
              )
            : caricando || livello == null || stato.valueOrNull == null
            ? const Center(child: FiammaCheGira())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                children: [
                  LivelloInGrande(
                    livello: livello,
                    xp: stato.value!.xp,
                    sfideCompletate: stato.value!.sfideCompletate,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Titolo(
                    'OGGI',
                    '${oggi.where((s) => s.stato == StatoSfida.completata).length}'
                        '/${oggi.length} · cambiano a mezzanotte',
                  ),
                  if (oggi.isEmpty)
                    const _Vuoto('Le sfide di oggi stanno arrivando.')
                  else
                    for (final voce in oggi) SfidaCard(voce: voce),
                  const SizedBox(height: AppSpacing.xl),
                  const _Titolo(
                    'TRAGUARDI',
                    'Non scadono: quello che fai resta.',
                  ),
                  if (traguardi.isEmpty)
                    const _Vuoto('Nessun traguardo, per ora.')
                  else
                    // **Due per riga, alti quanto serve.** Una griglia ad
                    // altezza fissa, su un Android piccolo con il testo
                    // ingrandito, tagliava il fondo dei mattoni.
                    for (var i = 0; i < traguardi.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: TraguardoMattone(voce: traguardi[i]),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: i + 1 < traguardi.length
                                    ? TraguardoMattone(voce: traguardi[i + 1])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

class _Titolo extends StatelessWidget {
  const _Titolo(this.titolo, this.nota);

  final String titolo;
  final String nota;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Text(
            titolo,
            style: texts.labelSmall?.copyWith(color: palette.accent),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              nota,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texts.bodySmall?.copyWith(color: palette.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vuoto extends StatelessWidget {
  const _Vuoto(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        testo,
        style: context.texts.bodySmall?.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    );
  }
}
